#!/bin/bash

# Test System - AI Workflow Demo
# Tests all deployed components

set -e

echo "Testing AI Workflow Demo"
echo "============================"

if [ -z "$GCP_PROJECT" ]; then
    echo "[ERROR] GCP_PROJECT not set"
    exit 1
fi

GCP_REGION=${GCP_REGION:-"us-central1"}

# Get service URLs
echo "Getting service URLs..."

SLACK_BOT_URL=$(gcloud functions describe slack-rag-bot \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --format='value(httpsTrigger.url)' 2>/dev/null || echo "")

SHOPIFY_URL=$(gcloud run services describe shopify-processor \
    --region=$GCP_REGION \
    --project=$GCP_PROJECT \
    --format='value(status.url)' 2>/dev/null || echo "")

echo ""

# Test 1: Slack Bot Health Check
echo "[1/7] Testing Slack Bot..."
if [ -n "$SLACK_BOT_URL" ]; then
    RESPONSE=$(curl -s $SLACK_BOT_URL)
    if [[ $RESPONSE == *"running"* ]]; then
        echo "   [OK] Slack Bot is healthy"
    else
        echo "   [WARNING] Slack Bot responded but unexpected response"
    fi
else
    echo "   [ERROR] Slack Bot not deployed"
fi

# Test 2: Slack Bot RAG Query
echo ""
echo "[2/7] Testing Slack Bot RAG..."
if [ -n "$SLACK_BOT_URL" ]; then
    RAG_RESPONSE=$(curl -s -X POST $SLACK_BOT_URL \
        -H "Content-Type: application/json" \
        -d '{
            "text": "How do I reset my password?",
            "user_id": "test_user"
        }')

    if [[ $RAG_RESPONSE == *"password"* ]] || [[ $RAG_RESPONSE == *"reset"* ]]; then
        echo "   [OK] RAG system working - got relevant answer"
        echo "   Response snippet: $(echo $RAG_RESPONSE | cut -c1-100)..."
    else
        echo "   [WARNING] RAG responded but answer may not be relevant"
        echo "   Response: $(echo $RAG_RESPONSE | cut -c1-200)"
    fi
else
    echo "   [SKIP] Skipped - Slack Bot not deployed"
fi

# Test 3: Shopify Processor Health
echo ""
echo "[3/7] Testing Shopify Processor..."
if [ -n "$SHOPIFY_URL" ]; then
    SHOPIFY_HEALTH=$(curl -s $SHOPIFY_URL)
    if [[ $SHOPIFY_HEALTH == *"healthy"* ]]; then
        echo "   [OK] Shopify Processor is healthy"
    else
        echo "   [WARNING] Unexpected response from Shopify Processor"
    fi
else
    echo "   [ERROR] Shopify Processor not deployed"
fi

# Test 4: Shopify Order Processing
echo ""
echo "[4/7] Testing Shopify Order Processing..."
if [ -n "$SHOPIFY_URL" ]; then
    ORDER_RESPONSE=$(curl -s -X POST ${SHOPIFY_URL}/test \
        -H "Content-Type: application/json")

    if [[ $ORDER_RESPONSE == *"success"* ]]; then
        echo "   [OK] Order processing working"
        echo "   $(echo $ORDER_RESPONSE | grep -o '"summary":"[^"]*"' || echo 'AI analysis complete')"
    else
        echo "   [WARNING] Order processing may have issues"
        echo "   Response: $(echo $ORDER_RESPONSE | cut -c1-200)"
    fi
else
    echo "   [SKIP] Skipped - Shopify Processor not deployed"
fi

# Test 5: BigQuery Tables
echo ""
echo "[5/7] Testing BigQuery..."
TABLE_COUNT=$(bq ls --project_id=$GCP_PROJECT knowledge_base 2>/dev/null | grep -c TABLE || echo "0")

if [ "$TABLE_COUNT" -gt "0" ]; then
    echo "   [OK] BigQuery dataset exists with $TABLE_COUNT tables"

    # Check for data in orders table
    ORDER_COUNT=$(bq query --use_legacy_sql=false --project_id=$GCP_PROJECT \
        "SELECT COUNT(*) as cnt FROM knowledge_base.orders" 2>/dev/null | \
        grep -oP '\d+' | head -1 || echo "0")

    if [ "$ORDER_COUNT" -gt "0" ]; then
        echo "   [OK] Found $ORDER_COUNT orders in database"
    else
        echo "   [INFO] No orders in database yet (run test endpoints to add data)"
    fi
else
    echo "   [ERROR] BigQuery dataset not found"
fi

# Test 6: Cloud Workflows
echo ""
echo "[6/7] Testing Cloud Workflows..."
WORKFLOW_COUNT=$(gcloud workflows list \
    --project=$GCP_PROJECT \
    --location=$GCP_REGION 2>/dev/null | grep -c "order-processing\|daily-analytics" || echo "0")

if [ "$WORKFLOW_COUNT" -gt "0" ]; then
    echo "   [OK] Found $WORKFLOW_COUNT workflow(s) deployed"
else
    echo "   [WARNING] No workflows found"
fi

# Test 7: Execute a test workflow
echo ""
echo "[7/7] Testing Workflow Execution..."
WORKFLOW_EXISTS=$(gcloud workflows describe order-processing-workflow \
    --location=$GCP_REGION \
    --project=$GCP_PROJECT 2>/dev/null || echo "")

if [ -n "$WORKFLOW_EXISTS" ]; then
    echo "   Executing test workflow..."

    EXECUTION_OUTPUT=$(gcloud workflows execute order-processing-workflow \
        --location=$GCP_REGION \
        --project=$GCP_PROJECT \
        --data='{"orderId":"test-123","orderNumber":"TEST-001","priority":"medium","riskScore":0.3}' \
        2>&1 || echo "execution_failed")

    if [[ $EXECUTION_OUTPUT != *"execution_failed"* ]]; then
        echo "   [OK] Workflow executed successfully"
    else
        echo "   [WARNING] Workflow execution may have issues (this is normal if dependencies aren't configured)"
    fi
else
    echo "   [SKIP] Skipped - Workflow not deployed"
fi

# Summary
echo ""
echo "============================"
echo "Test Summary"
echo "============================"
echo ""
echo "Service URLs:"
[ -n "$SLACK_BOT_URL" ] && echo "  Slack Bot: $SLACK_BOT_URL"
[ -n "$SHOPIFY_URL" ] && echo "  Shopify Processor: $SHOPIFY_URL"
echo ""
echo "Manual Tests:"
echo "  1. Test Slack: curl -X POST $SLACK_BOT_URL -H 'Content-Type: application/json' -d '{\"text\":\"How do I contact support?\"}'"
echo "  2. Test Shopify: curl -X POST ${SHOPIFY_URL}/test"
echo "  3. View BigQuery: https://console.cloud.google.com/bigquery?project=$GCP_PROJECT"
echo "  4. View Workflows: https://console.cloud.google.com/workflows?project=$GCP_PROJECT"
echo ""
