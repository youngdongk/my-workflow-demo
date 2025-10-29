# Usage Examples

Real-world examples of using the AI Workflow Demo components.

## Slack RAG Bot Examples

### Basic Question
```bash
curl -X POST https://REGION-PROJECT.cloudfunctions.net/slack-rag-bot \
  -H "Content-Type: application/json" \
  -d '{
    "text": "How do I reset my password?",
    "user_id": "U12345",
    "channel_id": "C12345"
  }'
```

**Expected Response:**
```json
{
  "response_type": "in_channel",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Question:* How do I reset my password?\n\n*Answer:*\nTo reset your password: 1) Go to login page 2) Click 'Forgot Password'..."
      }
    },
    {
      "type": "context",
      "elements": [{
        "type": "mrkdwn",
        "text": "*Sources:*\n• Password Reset Guide (relevance: 0.94)"
      }]
    }
  ]
}
```

### Multiple Related Questions
```bash
# Question 1: About refunds
curl -X POST $SLACK_BOT_URL \
  -H "Content-Type: application/json" \
  -d '{"text": "What is your refund policy?"}'

# Question 2: About shipping
curl -X POST $SLACK_BOT_URL \
  -H "Content-Type: application/json" \
  -d '{"text": "How long does shipping take?"}'

# Question 3: About API
curl -X POST $SLACK_BOT_URL \
  -H "Content-Type: application/json" \
  -d '{"text": "How do I use your API?"}'
```

## Shopify Order Processor Examples

### Test Endpoint (Sample Order)
```bash
curl -X POST https://REGION-run.app/test
```

**Response:**
```json
{
  "success": true,
  "orderId": 123456789,
  "orderNumber": "TEST-1001",
  "analysis": {
    "riskScore": 0.25,
    "priority": "medium",
    "summary": "Standard order with multiple items, low risk profile"
  }
}
```

### Real Shopify Webhook (Production)
```bash
# This is what Shopify sends
curl -X POST https://REGION-run.app/webhook/order-created \
  -H "Content-Type: application/json" \
  -d '{
    "id": 987654321,
    "order_number": "1234",
    "email": "customer@example.com",
    "customer": {
      "first_name": "Jane",
      "last_name": "Smith"
    },
    "total_price": "1249.99",
    "currency": "USD",
    "line_items": [
      {
        "title": "Premium Product X",
        "quantity": 2,
        "price": "499.99"
      },
      {
        "title": "Accessory Y",
        "quantity": 1,
        "price": "249.99"
      }
    ],
    "created_at": "2024-01-15T10:30:00Z"
  }'
```

**What Happens:**
1. AI analyzes the order
2. Risk score: 0.45 (medium)
3. Tags: ["high-value", "bulk-order"]
4. Stores in BigQuery
5. No workflow triggered (not high-risk)

### High-Risk Order Example
```bash
curl -X POST https://REGION-run.app/webhook/order-created \
  -H "Content-Type: application/json" \
  -d '{
    "id": 555555,
    "order_number": "5555",
    "email": "suspicious@temp-mail.com",
    "customer": {
      "first_name": "Test",
      "last_name": "User"
    },
    "total_price": "9999.99",
    "currency": "USD",
    "line_items": [
      {
        "title": "Expensive Item",
        "quantity": 50,
        "price": "199.99"
      }
    ],
    "created_at": "2024-01-15T03:00:00Z"
  }'
```

**What Happens:**
1. AI detects high risk (0.85)
2. Flags: ["unusual-quantity", "high-value", "suspicious-email"]
3. Priority: "high"
4. **Triggers workflow:**
   - Sends Slack alert
   - Creates manual review task
   - Updates Sheets immediately

## BigQuery Query Examples

### Find High-Value Customers
```sql
-- Run in BigQuery console
SELECT
  customer_email,
  COUNT(*) as order_count,
  SUM(total_amount) as lifetime_value,
  AVG(ai_risk_score) as avg_risk
FROM `your-project.knowledge_base.orders`
GROUP BY customer_email
HAVING order_count >= 3
ORDER BY lifetime_value DESC
LIMIT 20;
```

### Analyze Q&A Performance
```sql
-- Questions with low similarity (need better docs)
SELECT
  question,
  top_similarity,
  COUNT(*) as times_asked
FROM `your-project.knowledge_base.interactions`
WHERE top_similarity < 0.6
GROUP BY question, top_similarity
ORDER BY times_asked DESC, top_similarity ASC
LIMIT 10;
```

### Daily Revenue Trends
```sql
-- Last 30 days
SELECT
  DATE(created_at) as date,
  COUNT(*) as orders,
  SUM(total_amount) as revenue,
  AVG(total_amount) as avg_order_value,
  SUM(CASE WHEN ai_priority = 'high' THEN 1 ELSE 0 END) as priority_orders
FROM `your-project.knowledge_base.orders`
WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date
ORDER BY date DESC;
```

### Fraud Detection Analytics
```sql
-- Orders flagged for fraud
SELECT
  order_number,
  customer_email,
  total_amount,
  ai_risk_score,
  fraud_flags,
  ai_summary
FROM `your-project.knowledge_base.orders`
WHERE ARRAY_LENGTH(fraud_flags) > 0
  OR ai_risk_score > 0.8
ORDER BY ai_risk_score DESC, created_at DESC;
```

## Cloud Workflow Examples

### Trigger Order Processing Workflow
```bash
gcloud workflows execute order-processing-workflow \
  --location=us-central1 \
  --data='{
    "orderId": "12345",
    "orderNumber": "ORDER-100",
    "priority": "high",
    "riskScore": 0.85
  }'
```

### View Workflow Execution
```bash
# List recent executions
gcloud workflows executions list order-processing-workflow \
  --location=us-central1 \
  --limit=10

# Describe specific execution
gcloud workflows executions describe EXECUTION_ID \
  --workflow=order-processing-workflow \
  --location=us-central1
```

### Trigger Daily Analytics Manually
```bash
gcloud workflows execute daily-analytics-workflow \
  --location=us-central1
```

## Google Apps Script Examples

### Manual Dashboard Update
```javascript
// In Apps Script editor
function manualUpdate() {
  updateDashboard();
  Logger.log('Dashboard updated!');
}
```

### Custom Query Example
```javascript
// Add to Code.gs to create custom sheet
function createCustomReport() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = getOrCreateSheet(ss, 'Custom Report');

  const query = `
    SELECT
      customer_email,
      COUNT(*) as orders,
      SUM(total_amount) as total_spent
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    GROUP BY customer_email
    HAVING orders > 1
    ORDER BY total_spent DESC
  `;

  const results = runBigQueryQuery(query);

  sheet.clear();
  sheet.getRange(1, 1, 1, 3).setValues([['Email', 'Orders', 'Total Spent']]);
  sheet.getRange(2, 1, results.length, 3).setValues(results);
}
```

### Send Custom Alert
```javascript
function sendCustomAlert() {
  const highRiskQuery = `
    SELECT COUNT(*) as count
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE ai_risk_score > 0.8
      AND DATE(created_at) = CURRENT_DATE()
  `;

  const results = runBigQueryQuery(highRiskQuery);
  const count = results[0][0];

  if (count > 0) {
    MailApp.sendEmail(
      'admin@example.com',
      '⚠️ High Risk Orders Alert',
      `${count} high-risk orders detected today. Review immediately.`
    );
  }
}
```

## Integration Examples

### Configure Slack App

1. **Create Slack App:**
   - Go to https://api.slack.com/apps
   - Create New App → From scratch
   - Name: "AI Assistant"

2. **Enable Event Subscriptions:**
   - Features → Event Subscriptions → On
   - Request URL: `https://REGION-PROJECT.cloudfunctions.net/slack-rag-bot`
   - Subscribe to bot events: `app_mention`, `message.channels`

3. **Install to Workspace:**
   - OAuth & Permissions → Install to Workspace
   - Add to channel: `/invite @AI Assistant`

4. **Test:**
   ```
   @AI Assistant How do I reset my password?
   ```

### Configure Shopify Webhook

1. **In Shopify Admin:**
   - Settings → Notifications → Webhooks
   - Create webhook

2. **Configuration:**
   - Event: Order creation
   - Format: JSON
   - URL: `https://REGION-run.app/webhook/order-created`
   - API version: Latest

3. **Test:**
   - Create a test order in Shopify
   - Check Cloud Run logs for processing
   - Verify data in BigQuery

### Slack Notifications Setup

Update workflows with your Slack webhook:

```yaml
# In workflow YAML files
- send_notification:
    call: http.post
    args:
      url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
      headers:
        Content-Type: "application/json"
      body:
        text: "🚨 High priority order detected!"
```

Get webhook URL:
1. Go to https://api.slack.com/apps
2. Your App → Incoming Webhooks → Add New Webhook
3. Copy webhook URL

## Testing End-to-End

### Complete Flow Test
```bash
#!/bin/bash

echo "Testing complete AI workflow..."

# 1. Test Slack Bot
echo "1. Testing Slack RAG Bot..."
curl -X POST $SLACK_BOT_URL \
  -H "Content-Type: application/json" \
  -d '{"text": "How do I contact support?"}'

sleep 2

# 2. Test Order Processing
echo "2. Creating test order..."
curl -X POST ${SHOPIFY_URL}/test

sleep 2

# 3. Check BigQuery
echo "3. Checking BigQuery data..."
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) FROM knowledge_base.orders WHERE DATE(created_at) = CURRENT_DATE()"

# 4. Trigger workflow
echo "4. Triggering workflow..."
gcloud workflows execute order-processing-workflow \
  --data='{"orderId":"test","orderNumber":"TEST","priority":"high","riskScore":0.8}'

# 5. Update dashboard
echo "5. Dashboard will update on next scheduled run or manual trigger"

echo "✅ End-to-end test complete!"
```

## Monitoring Examples

### View Cloud Function Logs
```bash
# Recent logs
gcloud functions logs read slack-rag-bot \
  --region=us-central1 \
  --limit=50

# Filter errors
gcloud functions logs read slack-rag-bot \
  --region=us-central1 \
  --limit=50 \
  | grep ERROR
```

### View Cloud Run Logs
```bash
# Stream logs
gcloud run logs tail shopify-processor \
  --region=us-central1

# Last 100 entries
gcloud run logs read shopify-processor \
  --region=us-central1 \
  --limit=100
```

### Monitor Costs
```bash
# Check BigQuery costs (last 7 days)
bq ls --format=prettyjson --project_id=your-project | \
  jq '.[] | {dataset: .id, size: .location}'
```

## Customization Examples

### Add New Knowledge Base Document
```python
# Add to populate_knowledge_base.py
new_doc = {
    "content": "Your new help article content here...",
    "metadata": {
        "title": "New Feature Guide",
        "category": "features",
        "url": "https://help.example.com/new-feature"
    }
}

SAMPLE_DOCS.append(new_doc)
# Then run: python populate_knowledge_base.py
```

### Modify Risk Scoring Logic
```typescript
// In shopify-processor/src/index.ts
// Modify the prompt to adjust risk scoring criteria

const prompt = `Analyze this order and focus on:
- Quantity anomalies (> 20 items = high risk)
- Price patterns
- Email domain reputation
- Time of order (night orders = higher risk)
...`;
```

These examples should help you get started with the AI Workflow Demo! 🚀
