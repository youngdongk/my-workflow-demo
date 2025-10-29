# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Systems                             │
│  ┌──────────┐        ┌──────────┐        ┌──────────────┐          │
│  │  Slack   │        │ Shopify  │        │ Google       │          │
│  │ Messages │        │  Orders  │        │ Workspace    │          │
│  └────┬─────┘        └────┬─────┘        └──────┬───────┘          │
└───────┼──────────────────┼───────────────────────┼──────────────────┘
        │                  │                       │
        │ Webhook          │ Webhook               │ Manual/Schedule
        │                  │                       │
┌───────▼──────────────────▼───────────────────────▼──────────────────┐
│                       GCP Services Layer                             │
│                                                                      │
│  ┌────────────────────┐         ┌─────────────────────┐            │
│  │  Cloud Function    │         │   Cloud Run         │            │
│  │  (Slack RAG Bot)   │         │ (Shopify Processor) │            │
│  │                    │         │                     │            │
│  │  • Python 3.11     │         │  • TypeScript/Node  │            │
│  │  • RAG Pipeline    │         │  • AI Analysis      │            │
│  │  • Vertex AI       │         │  • Risk Scoring     │            │
│  └─────────┬──────────┘         └──────────┬──────────┘            │
│            │                               │                        │
│            │                               │                        │
│            ▼                               ▼                        │
│  ┌─────────────────────────────────────────────────────┐           │
│  │            Vertex AI (LLM & Embeddings)             │           │
│  │                                                     │           │
│  │  • Gemini 1.5 Flash (Text Generation)             │           │
│  │  • text-embedding-gecko (Vector Embeddings)       │           │
│  │  • RAG Context Retrieval                          │           │
│  │  • Sentiment & Risk Analysis                      │           │
│  └─────────────────┬───────────────────────────────────┘           │
│                    │                                                │
│                    ▼                                                │
│  ┌─────────────────────────────────────────────────────┐           │
│  │              BigQuery (Data Warehouse)              │           │
│  │                                                     │           │
│  │  Tables:                                            │           │
│  │  • documents (knowledge base + embeddings)         │           │
│  │  • interactions (Q&A logs)                         │           │
│  │  • orders (enriched order data)                    │           │
│  │  • workflow_executions (audit logs)                │           │
│  └────────────┬──────────────────────┬─────────────────┘           │
│               │                      │                             │
│               │                      │                             │
│  ┌────────────▼──────────┐  ┌────────▼─────────────────────┐      │
│  │  Cloud Workflows      │  │  Cloud Scheduler             │      │
│  │                       │  │                              │      │
│  │  • order-processing   │  │  • daily-analytics (9am)     │      │
│  │  • daily-analytics    │  │  • Triggers workflows        │      │
│  │  • Orchestration      │  └──────────────────────────────┘      │
│  └───────────────────────┘                                        │
│                                                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │
                             │ BigQuery API
                             │
┌────────────────────────────▼───────────────────────────────────────┐
│                    Google Apps Script                              │
│                                                                    │
│  • Scheduled updates (daily)                                      │
│  • Dashboard generation                                           │
│  • Email notifications                                            │
│  • Conditional formatting                                         │
│                                                                    │
│  Sheets:                                                          │
│  • Recent Orders  • Q&A Interactions                              │
│  • Analytics      • Alerts                                        │
└────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Slack Q&A Flow (RAG Pipeline)

```
User Question
    │
    ▼
Slack → Cloud Function (slack-rag-bot)
    │
    ├─► Generate embedding (Vertex AI)
    │
    ├─► Search similar docs (BigQuery vector search)
    │
    ├─► Retrieve top-K documents
    │
    ├─► Build context prompt
    │
    ├─► Generate answer (Vertex AI Gemini)
    │
    ├─► Log interaction (BigQuery)
    │
    ▼
Return answer to Slack
```

### 2. Shopify Order Processing Flow

```
New Order
    │
    ▼
Shopify → Cloud Run (shopify-processor)
    │
    ├─► Extract order data
    │
    ├─► Analyze with AI (Vertex AI Gemini)
    │   ├─► Risk scoring
    │   ├─► Sentiment analysis
    │   ├─► Priority classification
    │   └─► Fraud detection
    │
    ├─► Store enriched data (BigQuery)
    │
    ├─► Check if high-risk/priority
    │
    ├─► Trigger workflow (if needed)
    │   │
    │   ▼
    │   Cloud Workflow
    │   ├─► Send Slack alert
    │   ├─► Create review task
    │   ├─► Update Sheets
    │   └─► Generate recommendations
    │
    ▼
Return success response
```

### 3. Daily Analytics Flow

```
Cloud Scheduler (9am daily)
    │
    ▼
Trigger daily-analytics-workflow
    │
    ├─► Aggregate order metrics (BigQuery)
    │
    ├─► Aggregate Q&A metrics (BigQuery)
    │
    ├─► Generate AI summary (Vertex AI)
    │
    ├─► Check for anomalies
    │
    ├─► Send alerts (if needed)
    │
    ├─► Trigger Apps Script
    │
    ▼
Apps Script updates Google Sheets
    ├─► Recent Orders
    ├─► Q&A Interactions
    ├─► Analytics Dashboard
    └─► Alerts
```

## Technology Stack

### Backend Services

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Slack Bot | Cloud Functions + Python | Serverless Q&A endpoint |
| Order Processor | Cloud Run + TypeScript | Containerized order analysis |
| Orchestration | Cloud Workflows | Multi-step workflow coordination |
| Scheduling | Cloud Scheduler | Trigger daily jobs |

### AI & ML

| Component | Service | Model |
|-----------|---------|-------|
| Text Generation | Vertex AI | Gemini 1.5 Flash |
| Embeddings | Vertex AI | text-embedding-gecko@003 |
| RAG | Custom | Cosine similarity search |

### Data Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Data Warehouse | BigQuery | Structured data storage |
| Knowledge Base | BigQuery + JSON | Documents with embeddings |
| Analytics | BigQuery SQL | Queries and aggregations |

### Integration Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Automation | Apps Script | Google Sheets dashboards |
| Webhooks | HTTP/REST | Slack, Shopify integration |
| Notifications | Slack Webhooks | Real-time alerts |

## Security Considerations (Production)

**This is a DEMO - Not production-ready!**

For production, add:

1. **Authentication & Authorization**
   - API keys for webhooks
   - OAuth for user access
   - IAM roles for service accounts
   - Secret Manager for credentials

2. **Data Protection**
   - Encrypt data at rest (BigQuery encryption)
   - TLS for data in transit
   - PII data masking
   - Data retention policies

3. **Rate Limiting & Quotas**
   - Cloud Armor for DDoS protection
   - Rate limiting on endpoints
   - Cost controls and budgets

4. **Monitoring & Logging**
   - Cloud Monitoring dashboards
   - Alert policies
   - Error Reporting
   - Cloud Trace for latency tracking

5. **Compliance**
   - GDPR considerations
   - Data residency requirements
   - Audit logging

## Scalability

### Current Limits (Demo)
- Cloud Functions: 1 concurrent execution
- Cloud Run: 1 instance, 512MB RAM
- BigQuery: 100 concurrent queries
- Suitable for: < 1000 requests/day

### Production Scaling
- Cloud Functions: Auto-scale to 1000s
- Cloud Run: Auto-scale instances
- BigQuery: Petabyte-scale
- Add: Load balancer, CDN, caching

## Cost Optimization

### Current Demo Costs
- Cloud Functions: ~$0.01/day
- Cloud Run: ~$0.01/day
- BigQuery: ~$0.10/month
- Vertex AI: ~$0.001/request
- **Total: < $5/month**

### Production Optimization
- Use committed use discounts
- Implement caching layers
- Batch API requests
- Use cheaper regions
- Set up billing alerts

## Monitoring & Observability

### Metrics to Track
- Request latency (p50, p95, p99)
- Error rates
- LLM token usage
- BigQuery query costs
- Workflow success rates

### Logs
- Cloud Functions logs
- Cloud Run logs
- Workflow execution logs
- BigQuery audit logs

### Dashboards
- Google Sheets (business metrics)
- Cloud Monitoring (technical metrics)
- Custom dashboards via Looker/Data Studio

## Future Enhancements

1. **Advanced RAG**
   - Vector database (Vertex AI Vector Search)
   - Hybrid search (keyword + semantic)
   - Re-ranking models

2. **More Integrations**
   - Zendesk for support tickets
   - Stripe for payments
   - Salesforce for CRM

3. **Advanced AI**
   - Fine-tuned models
   - Multi-agent systems
   - Automated testing

4. **Real-time Features**
   - WebSocket connections
   - Streaming responses
   - Live dashboards

5. **Enhanced Analytics**
   - Predictive analytics
   - Customer segmentation
   - Anomaly detection ML models
