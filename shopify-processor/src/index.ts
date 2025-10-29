/**
 * Shopify Order Processor - Cloud Run Service
 * Receives order webhooks, analyzes with AI, stores enriched data
 */

import express, { Request, Response } from 'express';
import { BigQuery } from '@google-cloud/bigquery';
import { VertexAI } from '@google-cloud/vertexai';

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;
const PROJECT_ID = process.env.GCP_PROJECT || 'your-project-id';
const LOCATION = 'us-central1';

// Initialize clients
const bigquery = new BigQuery({ projectId: PROJECT_ID });
const vertexAI = new VertexAI({ project: PROJECT_ID, location: LOCATION });

interface ShopifyOrder {
  id: number;
  order_number: string;
  email: string;
  customer: {
    first_name: string;
    last_name: string;
  };
  total_price: string;
  currency: string;
  line_items: Array<{
    title: string;
    quantity: number;
    price: string;
  }>;
  created_at: string;
  shipping_address?: any;
  billing_address?: any;
}

interface AIAnalysis {
  riskScore: number;
  sentiment: string;
  priority: string;
  summary: string;
  tags: string[];
  fraudFlags: string[];
}

/**
 * Analyze order using Vertex AI Gemini
 */
async function analyzeOrder(order: ShopifyOrder): Promise<AIAnalysis> {
  const model = vertexAI.getGenerativeModel({
    model: 'gemini-1.5-flash',
  });

  // Build context about the order
  const orderContext = `
Order Analysis Request:
Order Number: ${order.order_number}
Customer: ${order.customer.first_name} ${order.customer.last_name}
Email: ${order.email}
Total: ${order.currency} ${order.total_price}
Items: ${order.line_items.map(item => `${item.quantity}x ${item.title} ($${item.price})`).join(', ')}
  `.trim();

  const prompt = `Analyze this e-commerce order and provide insights in JSON format:

${orderContext}

Provide analysis as JSON with these fields:
{
  "riskScore": <float 0-1, where 1 is highest risk>,
  "sentiment": <"positive" | "neutral" | "negative">,
  "priority": <"low" | "medium" | "high">,
  "summary": <one sentence summary>,
  "tags": <array of relevant tags like "high-value", "first-time", "bulk-order">,
  "fraudFlags": <array of potential fraud indicators, empty if none>
}

Consider:
- Order value and patterns
- Customer behavior signals
- Potential fraud indicators (mismatched info, unusual quantities, etc.)
- Priority based on value and complexity

Return ONLY the JSON, no other text.`;

  try {
    const result = await model.generateContent(prompt);
    const response = result.response;
    const text = response.candidates?.[0]?.content?.parts?.[0]?.text || '{}';

    // Parse JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in response');
    }

    const analysis: AIAnalysis = JSON.parse(jsonMatch[0]);
    return analysis;

  } catch (error) {
    console.error('Error analyzing order:', error);
    // Return default analysis on error
    return {
      riskScore: 0.5,
      sentiment: 'neutral',
      priority: 'medium',
      summary: 'Unable to analyze order',
      tags: ['analysis-failed'],
      fraudFlags: []
    };
  }
}

/**
 * Store enriched order data in BigQuery
 */
async function storeOrder(order: ShopifyOrder, analysis: AIAnalysis) {
  const table = bigquery.dataset('knowledge_base').table('orders');

  const row = {
    order_id: order.id.toString(),
    order_number: order.order_number,
    customer_email: order.email,
    customer_name: `${order.customer.first_name} ${order.customer.last_name}`,
    total_amount: parseFloat(order.total_price),
    currency: order.currency,
    items: JSON.stringify(order.line_items),
    created_at: order.created_at,
    ai_risk_score: analysis.riskScore,
    ai_sentiment: analysis.sentiment,
    ai_priority: analysis.priority,
    ai_summary: analysis.summary,
    ai_tags: analysis.tags,
    fraud_flags: analysis.fraudFlags,
  };

  await table.insert([row]);
  console.log(`✓ Stored order ${order.order_number} in BigQuery`);
}

/**
 * Trigger follow-up workflow if needed
 */
async function triggerWorkflow(order: ShopifyOrder, analysis: AIAnalysis) {
  // Trigger workflow for high-priority or high-risk orders
  if (analysis.priority === 'high' || analysis.riskScore > 0.7) {
    console.log(`🔔 High priority/risk order detected: ${order.order_number}`);

    // In a real system, trigger Cloud Workflow here
    // For demo, just log
    const workflowInput = {
      orderId: order.id,
      orderNumber: order.order_number,
      priority: analysis.priority,
      riskScore: analysis.riskScore,
      actions: ['notify_team', 'manual_review', 'update_sheets']
    };

    console.log('Workflow trigger:', JSON.stringify(workflowInput, null, 2));
  }
}

/**
 * Health check endpoint
 */
app.get('/', (req: Request, res: Response) => {
  res.json({
    service: 'Shopify Order Processor',
    status: 'healthy',
    version: '1.0.0'
  });
});

/**
 * Webhook endpoint for Shopify orders
 */
app.post('/webhook/order-created', async (req: Request, res: Response) => {
  try {
    const order: ShopifyOrder = req.body;

    console.log(`📦 Received order: ${order.order_number}`);

    // 1. Analyze order with AI
    console.log('🤖 Analyzing with Vertex AI...');
    const analysis = await analyzeOrder(order);
    console.log('Analysis:', analysis);

    // 2. Store enriched data
    console.log('💾 Storing in BigQuery...');
    await storeOrder(order, analysis);

    // 3. Trigger workflows if needed
    await triggerWorkflow(order, analysis);

    // 4. Return success
    res.status(200).json({
      success: true,
      orderId: order.id,
      orderNumber: order.order_number,
      analysis: {
        riskScore: analysis.riskScore,
        priority: analysis.priority,
        summary: analysis.summary
      }
    });

  } catch (error) {
    console.error('❌ Error processing order:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * Test endpoint with sample order
 */
app.post('/test', async (req: Request, res: Response) => {
  const sampleOrder: ShopifyOrder = {
    id: 123456789,
    order_number: 'TEST-1001',
    email: 'customer@example.com',
    customer: {
      first_name: 'John',
      last_name: 'Doe'
    },
    total_price: '459.99',
    currency: 'USD',
    line_items: [
      {
        title: 'Premium Widget',
        quantity: 3,
        price: '99.99'
      },
      {
        title: 'Deluxe Gadget',
        quantity: 1,
        price: '159.99'
      }
    ],
    created_at: new Date().toISOString()
  };

  // Process as webhook
  req.body = sampleOrder;
  return app._router.handle(
    { ...req, method: 'POST', url: '/webhook/order-created' },
    res,
    () => {}
  );
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Shopify Order Processor running on port ${PORT}`);
  console.log(`📍 Webhook: POST /webhook/order-created`);
  console.log(`🧪 Test: POST /test`);
});
