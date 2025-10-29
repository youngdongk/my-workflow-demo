"""
Slack RAG Bot - Cloud Function
Receives questions from Slack, uses RAG to find answers from knowledge base
"""

import functions_framework
from google.cloud import bigquery
from vertexai.language_models import TextEmbeddingModel, TextGenerationModel
import vertexai
import numpy as np
from flask import jsonify
import json

# Initialize Vertex AI
PROJECT_ID = "your-project-id"  # Set via environment variable
LOCATION = "us-central1"
vertexai.init(project=PROJECT_ID, location=LOCATION)

# Models
embedding_model = TextEmbeddingModel.from_pretrained("textembedding-gecko@003")
llm_model = TextGenerationModel.from_pretrained("gemini-1.5-flash")

# BigQuery client
bq_client = bigquery.Client()

def get_embedding(text: str) -> list:
    """Generate embedding for text using Vertex AI"""
    embeddings = embedding_model.get_embeddings([text])
    return embeddings[0].values

def cosine_similarity(a, b):
    """Calculate cosine similarity between two vectors"""
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def search_knowledge_base(query: str, top_k: int = 3) -> list:
    """
    Search knowledge base using semantic similarity
    Returns top_k most relevant documents
    """
    # Get query embedding
    query_embedding = get_embedding(query)

    # Fetch all documents from BigQuery
    # In production, use vector search or approximate nearest neighbors
    sql = """
        SELECT
            id,
            content,
            metadata,
            embedding
        FROM `{project}.knowledge_base.documents`
        LIMIT 100
    """.format(project=PROJECT_ID)

    results = bq_client.query(sql).result()

    # Calculate similarities
    docs_with_scores = []
    for row in results:
        if row.embedding:
            stored_embedding = json.loads(row.embedding)
            similarity = cosine_similarity(query_embedding, stored_embedding)
            docs_with_scores.append({
                'content': row.content,
                'metadata': row.metadata,
                'similarity': similarity
            })

    # Sort by similarity and return top_k
    docs_with_scores.sort(key=lambda x: x['similarity'], reverse=True)
    return docs_with_scores[:top_k]

def generate_answer(question: str, context_docs: list) -> str:
    """Generate answer using LLM with retrieved context"""

    # Build context from retrieved documents
    context = "\n\n".join([
        f"Document {i+1}:\n{doc['content']}"
        for i, doc in enumerate(context_docs)
    ])

    # Create prompt
    prompt = f"""You are a helpful assistant. Answer the question based on the context provided.
If the context doesn't contain relevant information, say so.

Context:
{context}

Question: {question}

Answer:"""

    # Generate response
    response = llm_model.predict(
        prompt,
        temperature=0.2,
        max_output_tokens=512,
    )

    return response.text

def log_interaction(question: str, answer: str, sources: list):
    """Log interaction to BigQuery for analytics"""
    table_id = f"{PROJECT_ID}.knowledge_base.interactions"

    rows = [{
        'timestamp': 'CURRENT_TIMESTAMP()',
        'question': question,
        'answer': answer,
        'sources_used': len(sources),
        'top_similarity': sources[0]['similarity'] if sources else 0
    }]

    # Insert via streaming
    errors = bq_client.insert_rows_json(table_id, rows)
    if errors:
        print(f"Errors logging interaction: {errors}")

@functions_framework.http
def slack_bot(request):
    """
    HTTP Cloud Function entrypoint
    Handles Slack slash commands and messages
    """

    # Parse Slack request
    if request.method == 'POST':
        data = request.get_json() or request.form.to_dict()

        # Handle Slack URL verification challenge
        if data.get('challenge'):
            return jsonify({'challenge': data['challenge']})

        # Extract question from Slack event
        question = None
        if 'event' in data:
            # Event API format
            event = data['event']
            if event.get('type') == 'app_mention':
                question = event.get('text', '').strip()
                # Remove bot mention
                question = ' '.join(question.split()[1:])
        elif 'text' in data:
            # Slash command format
            question = data.get('text', '').strip()

        if not question:
            return jsonify({
                'response_type': 'ephemeral',
                'text': 'Please ask a question!'
            })

        # RAG Pipeline
        try:
            # 1. Search knowledge base
            relevant_docs = search_knowledge_base(question, top_k=3)

            if not relevant_docs:
                return jsonify({
                    'response_type': 'in_channel',
                    'text': "I couldn't find relevant information in the knowledge base."
                })

            # 2. Generate answer
            answer = generate_answer(question, relevant_docs)

            # 3. Log interaction
            log_interaction(question, answer, relevant_docs)

            # 4. Format response for Slack
            sources_text = "\n".join([
                f"- {doc['metadata'].get('title', 'Document')} (relevance: {doc['similarity']:.2f})"
                for doc in relevant_docs[:3]
            ])

            response = {
                'response_type': 'in_channel',
                'blocks': [
                    {
                        'type': 'section',
                        'text': {
                            'type': 'mrkdwn',
                            'text': f"*Question:* {question}\n\n*Answer:*\n{answer}"
                        }
                    },
                    {
                        'type': 'context',
                        'elements': [
                            {
                                'type': 'mrkdwn',
                                'text': f"*Sources:*\n{sources_text}"
                            }
                        ]
                    }
                ]
            }

            return jsonify(response)

        except Exception as e:
            print(f"Error processing request: {str(e)}")
            return jsonify({
                'response_type': 'ephemeral',
                'text': f'Sorry, an error occurred: {str(e)}'
            }), 500

    return jsonify({'message': 'Slack RAG Bot is running!'})
