# 🚀 Quick Start Guide

Get the AI Workflow Demo running in 15 minutes!

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- Python 3.11+ and Node.js 18+ installed
- Basic familiarity with GCP console

## Step 1: Setup GCP Project (2 min)

```bash
# Set your project ID
export GCP_PROJECT="your-project-id"
export GCP_REGION="us-central1"

# Authenticate
gcloud auth login
gcloud config set project $GCP_PROJECT
```

## Step 2: Deploy All Services (5 min)

```bash
# Make deployment script executable
chmod +x deploy/deploy-all.sh

# Run deployment
cd deploy
./deploy-all.sh
```

This will:
- Enable required GCP APIs
- Create BigQuery dataset and tables
- Deploy Slack RAG Bot (Cloud Function)
- Deploy Shopify Processor (Cloud Run)
- Deploy Cloud Workflows
- Setup Cloud Scheduler

## Step 3: Populate Knowledge Base (2 min)

```bash
# Install Python dependencies
cd ../slack-rag-bot
pip install -r requirements.txt

# Update PROJECT_ID in the script
sed -i "s/your-project-id/$GCP_PROJECT/g" populate_knowledge_base.py

# Populate knowledge base with sample data
python populate_knowledge_base.py
```

You should see: "✓ Successfully inserted 8 documents!"

## Step 4: Test the System (3 min)

```bash
# Run comprehensive tests
cd ../deploy
chmod +x test-system.sh
./test-system.sh
```

### Manual Tests

**Test Slack RAG Bot:**
```bash
SLACK_BOT_URL=$(gcloud functions describe slack-rag-bot --region=$GCP_REGION --format='value(httpsTrigger.url)')

curl -X POST $SLACK_BOT_URL \
  -H "Content-Type: application/json" \
  -d '{"text": "How do I reset my password?"}'
```

Expected: JSON response with answer about password reset

**Test Shopify Order Processor:**
```bash
SHOPIFY_URL=$(gcloud run services describe shopify-processor --region=$GCP_REGION --format='value(status.url)')

curl -X POST ${SHOPIFY_URL}/test
```

Expected: JSON with AI analysis of test order

## Step 5: Setup Google Sheets (3 min)

1. Create new Google Sheet at [sheets.google.com](https://sheets.google.com)

2. Open Apps Script: Extensions → Apps Script

3. Copy code from `apps-script/Code.gs`

4. Update `PROJECT_ID` in the script

5. Save and run `onOpen` function (authorize when prompted)

6. Refresh sheet - you'll see "📊 Dashboard" menu

7. Click "📊 Dashboard" → "🔄 Update Now"

8. Watch as tables populate with data!

## Step 6: View Your Data

### BigQuery Console
```bash
# Open BigQuery
open "https://console.cloud.google.com/bigquery?project=$GCP_PROJECT"
```

Run a query:
```sql
SELECT * FROM `knowledge_base.orders` LIMIT 10;
```

### Cloud Workflows Console
```bash
# View workflows
open "https://console.cloud.google.com/workflows?project=$GCP_PROJECT"
```

Execute `order-processing-workflow` manually with test data:
```json
{
  "orderId": "12345",
  "orderNumber": "TEST-100",
  "priority": "high",
  "riskScore": 0.8
}
```

## What You've Built

### 1. Slack RAG Bot
- **Endpoint:** Cloud Function URL
- **What it does:** Answers questions using AI + knowledge base
- **Try it:** Send POST with `{"text": "your question"}`

### 2. Shopify Order Processor
- **Endpoint:** Cloud Run URL + `/webhook/order-created`
- **What it does:** Analyzes orders with AI, flags risks, stores in BigQuery
- **Try it:** POST to `/test` endpoint

### 3. Google Sheets Dashboard
- **What it does:** Auto-generates reports from BigQuery
- **Schedule:** Updates daily at 9am (or manual)
- **Contains:** Orders, Q&A logs, analytics, alerts

### 4. Cloud Workflows
- **order-processing-workflow:** Orchestrates order handling
- **daily-analytics-workflow:** Runs daily analytics and sends summaries

## Next Steps

### Connect to Real Slack Workspace

1. Create Slack app at [api.slack.com/apps](https://api.slack.com/apps)
2. Enable Event Subscriptions
3. Set Request URL to your Cloud Function URL
4. Subscribe to `app_mention` events
5. Install app to workspace

### Connect to Shopify

1. In Shopify admin: Settings → Notifications → Webhooks
2. Create webhook for "Order creation"
3. URL: `{your-cloud-run-url}/webhook/order-created`
4. Format: JSON

### Customize

- **Add more documents:** Edit `populate_knowledge_base.py`
- **Modify AI prompts:** Check `main.py` and `index.ts`
- **Add more workflows:** Create new YAML files in `workflows/`
- **Extend analytics:** Add queries in `bigquery/queries.sql`

## Troubleshooting

### "Permission denied" errors
```bash
# Ensure you're authenticated
gcloud auth application-default login
```

### "API not enabled" errors
```bash
# Enable manually
gcloud services enable aiplatform.googleapis.com
```

### BigQuery "not found" errors
```bash
# Recreate dataset
cd bigquery
bq mk --dataset knowledge_base
bq query --use_legacy_sql=false < schema.sql
```

### Function/service not responding
```bash
# Check logs
gcloud functions logs read slack-rag-bot --region=$GCP_REGION --limit 50
gcloud run logs read shopify-processor --region=$GCP_REGION --limit 50
```

## Clean Up

To delete all resources:
```bash
cd deploy
chmod +x cleanup.sh
./cleanup.sh
```

## Cost Estimate

For demo/testing (low volume):
- Cloud Functions: ~$0.01/day
- Cloud Run: ~$0.01/day
- BigQuery: ~$0.10/month (storage)
- Vertex AI: ~$0.001/request
- **Total: < $5/month** for testing

## Learn More

- [Google Cloud Workflows](https://cloud.google.com/workflows/docs)
- [Vertex AI](https://cloud.google.com/vertex-ai/docs)
- [BigQuery](https://cloud.google.com/bigquery/docs)
- [Apps Script](https://developers.google.com/apps-script)

## Need Help?

Check the individual component READMEs:
- `slack-rag-bot/` - RAG implementation details
- `shopify-processor/` - Order processing logic
- `apps-script/` - Sheets automation
- `workflows/` - Workflow definitions
- `bigquery/` - Database schema and queries

Enjoy building with AI! 🎉
