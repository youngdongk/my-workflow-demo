# AI-Powered Workflow Automation Demo

A collection of working demos showing how AI assistants and automation turn team workflows into reliable systems.

## What This Demonstrates

- **LLM-Powered Support Bot**: Slack integration with RAG (Retrieval Augmented Generation)
- **Smart Order Processing**: Shopify webhook → AI analysis → BigQuery storage
- **Sheets Automation**: Google Apps Script for automated reporting
- **Workflow Orchestration**: Cloud Workflows coordinating multiple services

## Architecture

```
Slack Messages → Cloud Function → Vertex AI (RAG) → BigQuery
Shopify Orders → Cloud Run → LLM Analysis → BigQuery → Sheets
Google Sheets ← Apps Script ← BigQuery Analytics
```

## Project Structure

```
├── slack-rag-bot/          # Python Cloud Function - Slack support bot with RAG
├── shopify-processor/      # TypeScript Cloud Run - Order intelligence
├── apps-script/            # Google Apps Script - Sheets automation
├── workflows/              # GCP Workflows - Orchestration
├── bigquery/               # SQL schemas and queries
├── shared/                 # Shared utilities and configs
└── deploy/                 # Deployment scripts
```

## Components

### 1. Slack RAG Bot (Python)
- Receives questions via Slack webhook
- Uses Vertex AI embeddings for semantic search
- Retrieves relevant context from BigQuery
- Generates answers using Gemini LLM

### 2. Shopify Order Processor (TypeScript)
- Webhook endpoint for new orders
- LLM extracts insights and flags issues
- Stores enriched data in BigQuery
- Triggers workflow for follow-up actions

### 3. Google Sheets Automation (Apps Script)
- Auto-generates reports from BigQuery
- Updates dashboards on schedule
- Sends notifications for anomalies

### 4. Cloud Workflow Orchestration
- Coordinates multi-step processes
- Error handling and retries
- Integrates all services

## Tech Stack

- **LLM**: Google Vertex AI (Gemini, text-embeddings)
- **Compute**: Cloud Functions, Cloud Run
- **Storage**: BigQuery
- **Orchestration**: Cloud Workflows
- **Integrations**: Slack, Shopify, Google Workspace

## Quick Deploy

```bash
# Set your GCP project
export GCP_PROJECT="your-project-id"
export GCP_REGION="us-central1"

# Deploy all components
cd deploy
./deploy-all.sh
```

## Usage Examples

**Slack Bot:**
```
@bot How do I reset my password?
→ Bot searches knowledge base and provides answer with sources
```

**Shopify Integration:**
```
New order arrives → AI analyzes for fraud/priority → Updates BigQuery → Notifies team
```

**Sheets Automation:**
```
Daily at 9am → Query BigQuery → Update dashboard → Email summary
```

## Notes

This is a DEMO for learning and prototyping:
- No authentication/security implemented
- Simplified error handling
- Not production-ready
- Use for inspiration and experimentation!
