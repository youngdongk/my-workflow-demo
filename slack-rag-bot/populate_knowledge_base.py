"""
Script to populate BigQuery knowledge base with sample documents
Run this once to seed the knowledge base with embeddings
"""

from google.cloud import bigquery
from vertexai.language_models import TextEmbeddingModel
import vertexai
import json

PROJECT_ID = "your-project-id"
LOCATION = "us-central1"

# Initialize
vertexai.init(project=PROJECT_ID, location=LOCATION)
embedding_model = TextEmbeddingModel.from_pretrained("textembedding-gecko@003")
bq_client = bigquery.Client()

# Sample knowledge base documents
SAMPLE_DOCS = [
    {
        "content": "To reset your password: 1) Go to login page 2) Click 'Forgot Password' 3) Enter your email 4) Check your inbox for reset link 5) Click link and create new password. Password must be at least 8 characters with numbers and symbols.",
        "metadata": {"title": "Password Reset Guide", "category": "account", "url": "https://help.example.com/password-reset"}
    },
    {
        "content": "Our refund policy: You can request a refund within 30 days of purchase. Items must be unused and in original packaging. Digital products are non-refundable. To request a refund, email support@example.com with your order number.",
        "metadata": {"title": "Refund Policy", "category": "billing", "url": "https://help.example.com/refunds"}
    },
    {
        "content": "To integrate with our API: 1) Sign up for API key at developer portal 2) Include API key in Authorization header 3) Base URL is api.example.com/v1 4) Rate limit is 1000 requests/hour 5) Use webhooks for real-time updates.",
        "metadata": {"title": "API Integration Guide", "category": "developer", "url": "https://help.example.com/api"}
    },
    {
        "content": "Shipping information: Standard shipping takes 5-7 business days. Express shipping takes 2-3 days. International shipping takes 10-14 days. Free shipping on orders over $50. Track your order at track.example.com with your order number.",
        "metadata": {"title": "Shipping Guide", "category": "orders", "url": "https://help.example.com/shipping"}
    },
    {
        "content": "How to contact support: Email us at support@example.com (response within 24h). Live chat available Mon-Fri 9am-5pm EST. Phone support: 1-800-EXAMPLE. For urgent issues, use live chat. Include your account email in all requests.",
        "metadata": {"title": "Contact Support", "category": "support", "url": "https://help.example.com/contact"}
    },
    {
        "content": "Account security best practices: Enable two-factor authentication in settings. Use unique password for your account. Don't share login credentials. Review login activity regularly. Report suspicious activity immediately to security@example.com.",
        "metadata": {"title": "Security Best Practices", "category": "security", "url": "https://help.example.com/security"}
    },
    {
        "content": "Product features: Our premium plan includes unlimited storage, priority support, advanced analytics, custom branding, API access, and SSO integration. Standard plan has 100GB storage and email support. Free plan limited to 10GB.",
        "metadata": {"title": "Product Features", "category": "product", "url": "https://help.example.com/features"}
    },
    {
        "content": "Troubleshooting login issues: Clear browser cache and cookies. Try incognito mode. Check if Caps Lock is on. Verify you're using correct email. Reset password if needed. Disable VPN if connected. Contact support if issue persists.",
        "metadata": {"title": "Login Troubleshooting", "category": "troubleshooting", "url": "https://help.example.com/login-issues"}
    }
]

def generate_embeddings(texts: list) -> list:
    """Generate embeddings for list of texts"""
    embeddings = embedding_model.get_embeddings(texts)
    return [emb.values for emb in embeddings]

def populate_knowledge_base():
    """Populate BigQuery with documents and embeddings"""

    print("Generating embeddings for documents...")
    contents = [doc["content"] for doc in SAMPLE_DOCS]
    embeddings = generate_embeddings(contents)

    print("Preparing rows for BigQuery...")
    rows = []
    for i, doc in enumerate(SAMPLE_DOCS):
        rows.append({
            "id": f"doc_{i+1}",
            "content": doc["content"],
            "metadata": json.dumps(doc["metadata"]),
            "embedding": json.dumps(embeddings[i]),
            "created_at": "CURRENT_TIMESTAMP()"
        })

    # Insert into BigQuery
    table_id = f"{PROJECT_ID}.knowledge_base.documents"

    print(f"Inserting {len(rows)} documents into {table_id}...")
    errors = bq_client.insert_rows_json(table_id, rows)

    if errors:
        print(f"Errors occurred: {errors}")
    else:
        print(f"[OK] Successfully inserted {len(rows)} documents!")

    # Show sample
    print("\nSample documents:")
    for doc in SAMPLE_DOCS[:3]:
        print(f"  - {doc['metadata']['title']}")

if __name__ == "__main__":
    populate_knowledge_base()
