#!/bin/bash

# Deploy All Components - AI Workflow Demo
# Run this script to deploy all services to GCP

set -e  # Exit on error

echo "AI Workflow Demo - Full Deployment"
echo "======================================"

# Check if GCP_PROJECT is set
if [ -z "$GCP_PROJECT" ]; then
    echo "[ERROR] GCP_PROJECT environment variable not set"
    echo "   Run: export GCP_PROJECT='your-project-id'"
    exit 1
fi

if [ -z "$GCP_REGION" ]; then
    export GCP_REGION="us-central1"
    echo "[INFO] Using default region: $GCP_REGION"
fi

echo ""
echo "Project: $GCP_PROJECT"
echo "Region: $GCP_REGION"
echo ""

# Confirm deployment
read -p "Deploy to this project? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Enable required APIs
echo ""
echo "[1/6] Enabling GCP APIs..."
gcloud services enable \
    cloudfunctions.googleapis.com \
    run.googleapis.com \
    workflows.googleapis.com \
    bigquery.googleapis.com \
    aiplatform.googleapis.com \
    cloudbuild.googleapis.com \
    --project=$GCP_PROJECT

echo "[OK] APIs enabled"

# Deploy BigQuery
echo ""
echo "[2/6] Setting up BigQuery..."
cd ../bigquery
bq mk --dataset --location=$GCP_REGION ${GCP_PROJECT}:knowledge_base || echo "Dataset already exists"
bq query --use_legacy_sql=false < schema.sql
echo "[OK] BigQuery setup complete"

# Deploy Slack RAG Bot (Cloud Function)
echo ""
echo "[3/6] Deploying Slack RAG Bot..."
cd ../slack-rag-bot

gcloud functions deploy slack-rag-bot \
    --runtime=python311 \
    --trigger-http \
    --allow-unauthenticated \
    --entry-point=slack_bot \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --set-env-vars=GCP_PROJECT=$GCP_PROJECT \
    --memory=512MB \
    --timeout=60s

SLACK_BOT_URL=$(gcloud functions describe slack-rag-bot --region=$GCP_REGION --project=$GCP_PROJECT --format='value(httpsTrigger.url)')
echo "[OK] Slack Bot deployed at: $SLACK_BOT_URL"

# Deploy Shopify Order Processor (Cloud Run)
echo ""
echo "[4/6] Deploying Shopify Order Processor..."
cd ../shopify-processor

gcloud builds submit --tag gcr.io/$GCP_PROJECT/shopify-processor --project=$GCP_PROJECT

gcloud run deploy shopify-processor \
    --image gcr.io/$GCP_PROJECT/shopify-processor \
    --platform managed \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --allow-unauthenticated \
    --set-env-vars=GCP_PROJECT=$GCP_PROJECT \
    --memory=512Mi \
    --timeout=60

SHOPIFY_URL=$(gcloud run services describe shopify-processor --region=$GCP_REGION --project=$GCP_PROJECT --format='value(status.url)')
echo "[OK] Shopify Processor deployed at: $SHOPIFY_URL"

# Deploy Workflows
echo ""
echo "[5/6] Deploying Cloud Workflows..."
cd ../workflows

gcloud workflows deploy order-processing-workflow \
    --source=order-processing-workflow.yaml \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT

gcloud workflows deploy daily-analytics-workflow \
    --source=daily-analytics-workflow.yaml \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT

echo "[OK] Workflows deployed"

# Setup scheduled workflow execution
echo ""
echo "[6/6] Setting up scheduled workflows..."

# Create Cloud Scheduler job for daily analytics
gcloud scheduler jobs create http daily-analytics-job \
    --location=$GCP_REGION \
    --schedule="0 9 * * *" \
    --uri="https://workflowexecutions.googleapis.com/v1/projects/$GCP_PROJECT/locations/$GCP_REGION/workflows/daily-analytics-workflow/executions" \
    --http-method=POST \
    --oauth-service-account-email="${GCP_PROJECT}@appspot.gserviceaccount.com" \
    --project=$GCP_PROJECT \
    || echo "Scheduler job already exists"

echo "[OK] Scheduler configured"

# Summary
echo ""
echo "======================================"
echo "[SUCCESS] Deployment Complete!"
echo "======================================"
echo ""
echo "Next Steps:"
echo ""
echo "1. Populate Knowledge Base:"
echo "   cd slack-rag-bot"
echo "   python populate_knowledge_base.py"
echo ""
echo "2. Configure Slack Webhook:"
echo "   URL: $SLACK_BOT_URL"
echo ""
echo "3. Configure Shopify Webhook:"
echo "   URL: ${SHOPIFY_URL}/webhook/order-created"
echo ""
echo "4. Setup Google Apps Script:"
echo "   Follow apps-script/README.md"
echo ""
echo "5. Test the system:"
echo "   curl -X POST ${SHOPIFY_URL}/test"
echo ""
echo "View data in BigQuery:"
echo "   https://console.cloud.google.com/bigquery?project=$GCP_PROJECT"
echo ""
echo "View Workflows:"
echo "   https://console.cloud.google.com/workflows?project=$GCP_PROJECT"
echo ""
