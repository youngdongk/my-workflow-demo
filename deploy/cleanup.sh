#!/bin/bash

# Cleanup Script - AI Workflow Demo
# Removes all deployed resources from GCP

set -e

echo "AI Workflow Demo - Cleanup"
echo "=============================="

if [ -z "$GCP_PROJECT" ]; then
    echo "[ERROR] GCP_PROJECT not set"
    exit 1
fi

GCP_REGION=${GCP_REGION:-"us-central1"}

echo ""
echo "[WARNING] This will delete all demo resources from:"
echo "   Project: $GCP_PROJECT"
echo "   Region: $GCP_REGION"
echo ""
echo "This includes:"
echo "  - Cloud Functions"
echo "  - Cloud Run services"
echo "  - Cloud Workflows"
echo "  - BigQuery dataset (knowledge_base)"
echo "  - Cloud Scheduler jobs"
echo ""

read -p "Are you sure? Type 'DELETE' to confirm: " -r
echo

if [[ $REPLY != "DELETE" ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."

# Delete Cloud Function
echo ""
echo "[1/6] Deleting Cloud Functions..."
gcloud functions delete slack-rag-bot \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --quiet 2>/dev/null && echo "   [OK] Deleted slack-rag-bot" || echo "   [INFO] slack-rag-bot not found"

# Delete Cloud Run service
echo ""
echo "[2/6] Deleting Cloud Run services..."
gcloud run services delete shopify-processor \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --quiet 2>/dev/null && echo "   [OK] Deleted shopify-processor" || echo "   [INFO] shopify-processor not found"

# Delete Cloud Workflows
echo ""
echo "[3/6] Deleting Cloud Workflows..."
gcloud workflows delete order-processing-workflow \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT \
    --quiet 2>/dev/null && echo "   [OK] Deleted order-processing-workflow" || echo "   [INFO] order-processing-workflow not found"

gcloud workflows delete daily-analytics-workflow \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT \
    --quiet 2>/dev/null && echo "   [OK] Deleted daily-analytics-workflow" || echo "   [INFO] daily-analytics-workflow not found"

# Delete Cloud Scheduler jobs
echo ""
echo "[4/6] Deleting Cloud Scheduler jobs..."
gcloud scheduler jobs delete daily-analytics-job \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT \
    --quiet 2>/dev/null && echo "   [OK] Deleted daily-analytics-job" || echo "   [INFO] daily-analytics-job not found"

# Delete BigQuery dataset
echo ""
echo "[5/6] Deleting BigQuery dataset..."
read -p "Delete BigQuery dataset 'knowledge_base' and ALL data? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    bq rm -r -f -d ${GCP_PROJECT}:knowledge_base 2>/dev/null && \
        echo "   [OK] Deleted knowledge_base dataset" || \
        echo "   [INFO] knowledge_base dataset not found"
else
    echo "   [SKIP] Skipped BigQuery deletion"
fi

# Delete container images
echo ""
echo "[6/6] Deleting container images..."
gcloud container images delete gcr.io/$GCP_PROJECT/shopify-processor \
    --quiet 2>/dev/null && echo "   [OK] Deleted container image" || echo "   [INFO] Container image not found"

echo ""
echo "=============================="
echo "[SUCCESS] Cleanup Complete!"
echo "=============================="
echo ""
echo "Note: Google Apps Script must be deleted manually from:"
echo "https://script.google.com"
echo ""
