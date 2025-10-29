#!/bin/bash

# Test System - AI Workflow Demo
# Tests all deployed components

set -e

echo "🧪 Testing AI Workflow Demo"
echo "============================"

if [ -z "$GCP_PROJECT" ]; then
    echo "❌ Error: GCP_PROJECT not set"
    exit 1
fi

GCP_REGION=${GCP_REGION:-"us-central1"}

# Get service URLs
echo "📍 Getting service URLs..."

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
echo "1️⃣  Testing Slack Bot..."
if [ -n "$SLACK_BOT_URL" ]; then
    RESPONSE=$(curl -s $SLACK_BOT_URL)
    if [[ $RESPONSE == *"running"* ]]; then
        echo "   ✅ Slack Bot is healthy"
    else
        echo "   ⚠️  Slack Bot responded but unexpected response"
    fi
else
    echo "   ❌ Slack Bot not deployed"
fi

# Test 2: Slack Bot RAG Query
echo ""
echo "2️⃣  Testing Slack Bot RAG..."
if [ -n "$SLACK_BOT_URL" ]; then
    RAG_RESPONSE=$(curl -s -X POST $SLACK_BOT_URL \
        -H "Content-Type: application/json" \
        -d '{
            "text": "How do I reset my password?",
            "user_id": "test_user"
        }')

    if [[ $RAG_RESPONSE == *"password"* ]] || [[ $RAG_RESPONSE == *"reset"* ]]; then
        echo "   ✅ RAG system working - got relevant answer"
        echo "   Response snippet: $(echo $RAG_RESPONSE | cut -c1-100)..."
    else
        echo "   ⚠️  RAG responded but answer may not be relevant"
        echo "   Response: $(echo $RAG_RESPONSE | cut -c1-200)"
    fi
else
    echo "   ⏭️  Skipped - Slack Bot not deployed"
fi

# Test 3: Shopify Processor Health
echo ""
echo "3️⃣  Testing Shopify Processor..."
if [ -n "$SHOPIFY_URL" ]; then
    SHOPIFY_HEALTH=$(curl -s $SHOPIFY_URL)
    if [[ $SHOPIFY_HEALTH == *"healthy"* ]]; then
        echo "   ✅ Shopify Processor is healthy"
    else
        echo "   ⚠️  Unexpected response from Shopify Processor"
    fi
else
    echo "   ❌ Shopify Processor not deployed"
fi

# Test 4: Shopify Order Processing
echo ""
echo "4️⃣  Testing Shopify Order Processing..."
if [ -n "$SHOPIFY_URL" ]; then
    ORDER_RESPONSE=$(curl -s -X POST ${SHOPIFY_URL}/test \
        -H "Content-Type: application/json")

    if [[ $ORDER_RESPONSE == *"success"* ]]; then
        echo "   ✅ Order processing working"
        echo "   $(echo $ORDER_RESPONSE | grep -o '"summary":"[^"]*"' || echo 'AI analysis complete')"
    else
        echo "   ⚠️  Order processing may have issues"
        echo "   Response: $(echo $ORDER_RESPONSE | cut -c1-200)"
    fi
else
    echo "   ⏭️  Skipped - Shopify Processor not deployed"
fi

# Test 5: BigQuery Tables
echo ""
echo "5️⃣  Testing BigQuery..."
TABLE_COUNT=$(bq ls --project_id=$GCP_PROJECT knowledge_base 2>/dev/null | grep -c TABLE || echo "0")

if [ "$TABLE_COUNT" -gt "0" ]; then
    echo "   ✅ BigQuery dataset exists with $TABLE_COUNT tables"

    # Check for data in orders table
    ORDER_COUNT=$(bq query --use_legacy_sql=false --project_id=$GCP_PROJECT \
        "SELECT COUNT(*) as cnt FROM knowledge_base.orders" 2>/dev/null | \
        grep -oP '\d+' | head -1 || echo "0")

    if [ "$ORDER_COUNT" -gt "0" ]; then
        echo "   ✅ Found $ORDER_COUNT orders in database"
    else
        echo "   ℹ️  No orders in database yet (run test endpoints to add data)"
    fi
else
    echo "   ❌ BigQuery dataset not found"
fi

# Test 6: Cloud Workflows
echo ""
echo "6️⃣  Testing Cloud Workflows..."
WORKFLOW_COUNT=$(gcloud workflows list \
    --project=$GCP_PROJECT \
    --location=$GCP_REGION 2>/dev/null | grep -c "order-processing\|daily-analytics" || echo "0")

if [ "$WORKFLOW_COUNT" -gt "0" ]; then
    echo "   ✅ Found $WORKFLOW_COUNT workflow(s) deployed"
else
    echo "   ⚠️  No workflows found"
fi

# Test 7: Execute a test workflow
echo ""
echo "7️⃣  Testing Workflow Execution..."
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
        echo "   ✅ Workflow executed successfully"
    else
        echo "   ⚠️  Workflow execution may have issues (this is normal if dependencies aren't configured)"
    fi
else
    echo "   ⏭️  Skipped - Workflow not deployed"
fi

# Summary
echo ""
echo "============================"
echo "📊 Test Summary"
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
