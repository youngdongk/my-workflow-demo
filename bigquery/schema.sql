-- BigQuery Schema for AI Workflow Demo
-- Create dataset and tables for storing knowledge base, interactions, and order data

-- Create dataset
CREATE SCHEMA IF NOT EXISTS `knowledge_base`
OPTIONS (
  description = 'Knowledge base for RAG system and workflow data',
  location = 'us-central1'
);

-- Documents table (for RAG knowledge base)
CREATE OR REPLACE TABLE `knowledge_base.documents` (
  id STRING NOT NULL,
  content STRING NOT NULL,
  metadata JSON,
  embedding JSON,  -- Storing as JSON array for demo; use vector search in production
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Interactions table (log Q&A interactions)
CREATE OR REPLACE TABLE `knowledge_base.interactions` (
  id STRING DEFAULT GENERATE_UUID(),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  question STRING,
  answer STRING,
  sources_used INT64,
  top_similarity FLOAT64,
  user_id STRING,
  channel_id STRING
);

-- Orders table (Shopify order data with AI analysis)
CREATE OR REPLACE TABLE `knowledge_base.orders` (
  order_id STRING NOT NULL,
  order_number STRING,
  customer_email STRING,
  customer_name STRING,
  total_amount FLOAT64,
  currency STRING,
  items JSON,
  created_at TIMESTAMP,
  -- AI-generated fields
  ai_risk_score FLOAT64,
  ai_sentiment STRING,
  ai_priority STRING,
  ai_summary STRING,
  ai_tags ARRAY<STRING>,
  fraud_flags ARRAY<STRING>,
  processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Analytics view for daily interactions
CREATE OR REPLACE VIEW `knowledge_base.daily_interaction_stats` AS
SELECT
  DATE(timestamp) as date,
  COUNT(*) as total_questions,
  AVG(top_similarity) as avg_similarity,
  COUNT(DISTINCT user_id) as unique_users
FROM `knowledge_base.interactions`
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Analytics view for high-value orders
CREATE OR REPLACE VIEW `knowledge_base.high_value_orders` AS
SELECT
  order_id,
  order_number,
  customer_email,
  total_amount,
  ai_risk_score,
  ai_priority,
  ai_summary,
  created_at
FROM `knowledge_base.orders`
WHERE total_amount > 500 OR ai_priority = 'high'
ORDER BY created_at DESC;

-- Workflow execution logs
CREATE OR REPLACE TABLE `knowledge_base.workflow_executions` (
  execution_id STRING DEFAULT GENERATE_UUID(),
  workflow_name STRING,
  status STRING,  -- 'running', 'completed', 'failed'
  input JSON,
  output JSON,
  error_message STRING,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  completed_at TIMESTAMP,
  duration_seconds FLOAT64
);
