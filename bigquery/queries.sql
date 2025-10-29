-- Useful BigQuery queries for analytics and monitoring

-- 1. Find most common questions
SELECT
  question,
  COUNT(*) as ask_count,
  AVG(top_similarity) as avg_relevance
FROM `knowledge_base.interactions`
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY question
ORDER BY ask_count DESC
LIMIT 10;

-- 2. Questions with low relevance (need better docs)
SELECT
  question,
  top_similarity,
  timestamp
FROM `knowledge_base.interactions`
WHERE top_similarity < 0.7
ORDER BY timestamp DESC
LIMIT 20;

-- 3. High-risk orders needing attention
SELECT
  order_id,
  order_number,
  customer_email,
  total_amount,
  ai_risk_score,
  fraud_flags,
  created_at
FROM `knowledge_base.orders`
WHERE ai_risk_score > 0.7 OR ARRAY_LENGTH(fraud_flags) > 0
ORDER BY ai_risk_score DESC, created_at DESC;

-- 4. Daily order summary with AI insights
SELECT
  DATE(created_at) as order_date,
  COUNT(*) as total_orders,
  SUM(total_amount) as revenue,
  AVG(ai_risk_score) as avg_risk,
  SUM(CASE WHEN ai_priority = 'high' THEN 1 ELSE 0 END) as high_priority_orders,
  SUM(CASE WHEN ARRAY_LENGTH(fraud_flags) > 0 THEN 1 ELSE 0 END) as flagged_orders
FROM `knowledge_base.orders`
WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY order_date
ORDER BY order_date DESC;

-- 5. Most valuable customers (based on AI sentiment)
SELECT
  customer_email,
  COUNT(*) as order_count,
  SUM(total_amount) as lifetime_value,
  AVG(ai_risk_score) as avg_risk,
  ARRAY_AGG(DISTINCT ai_sentiment IGNORE NULLS) as sentiments
FROM `knowledge_base.orders`
GROUP BY customer_email
HAVING order_count > 1
ORDER BY lifetime_value DESC
LIMIT 50;

-- 6. Workflow performance metrics
SELECT
  workflow_name,
  status,
  COUNT(*) as execution_count,
  AVG(duration_seconds) as avg_duration,
  MAX(duration_seconds) as max_duration,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failure_count
FROM `knowledge_base.workflow_executions`
WHERE DATE(started_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY workflow_name, status
ORDER BY workflow_name, execution_count DESC;

-- 7. Knowledge base coverage (which docs are most useful)
SELECT
  JSON_EXTRACT_SCALAR(d.metadata, '$.title') as doc_title,
  JSON_EXTRACT_SCALAR(d.metadata, '$.category') as category,
  COUNT(i.id) as times_referenced
FROM `knowledge_base.documents` d
LEFT JOIN `knowledge_base.interactions` i
  ON STRPOS(i.answer, JSON_EXTRACT_SCALAR(d.metadata, '$.title')) > 0
GROUP BY doc_title, category
ORDER BY times_referenced DESC;

-- 8. Hourly interaction patterns (when is bot most used)
SELECT
  EXTRACT(HOUR FROM timestamp) as hour,
  EXTRACT(DAYOFWEEK FROM timestamp) as day_of_week,
  COUNT(*) as interaction_count
FROM `knowledge_base.interactions`
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY hour, day_of_week
ORDER BY interaction_count DESC;
