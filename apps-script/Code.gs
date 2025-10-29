/**
 * Google Apps Script - Automated Dashboard Generator
 * Pulls data from BigQuery and creates/updates Google Sheets dashboards
 *
 * Setup:
 * 1. Create new Google Sheet
 * 2. Extensions > Apps Script
 * 3. Copy this code
 * 4. Enable BigQuery API in GCP Console
 * 5. Set up time-based trigger for updateDashboard()
 */

const PROJECT_ID = 'your-project-id';
const DATASET = 'knowledge_base';

/**
 * Main function to update dashboard
 * Run this manually or set up a trigger (daily at 9am)
 */
function updateDashboard() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  Logger.log('[INFO] Starting dashboard update...');

  // Update each sheet
  updateOrdersSheet(ss);
  updateInteractionsSheet(ss);
  updateAnalyticsSheet(ss);
  updateAlertsSheet(ss);

  // Update timestamp
  const metaSheet = getOrCreateSheet(ss, 'Metadata');
  metaSheet.getRange('A1').setValue('Last Updated:');
  metaSheet.getRange('B1').setValue(new Date());

  Logger.log('[SUCCESS] Dashboard updated successfully!');

  // Send notification email
  sendUpdateNotification();
}

/**
 * Update Orders sheet with recent orders
 */
function updateOrdersSheet(ss) {
  const sheet = getOrCreateSheet(ss, 'Recent Orders');

  const query = `
    SELECT
      order_number,
      customer_name,
      customer_email,
      total_amount,
      currency,
      ai_priority,
      ai_risk_score,
      ai_summary,
      ARRAY_TO_STRING(ai_tags, ', ') as tags,
      created_at
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    ORDER BY created_at DESC
    LIMIT 100
  `;

  const results = runBigQueryQuery(query);

  // Clear and update
  sheet.clear();

  // Headers
  const headers = [
    'Order #', 'Customer', 'Email', 'Amount', 'Currency',
    'Priority', 'Risk Score', 'AI Summary', 'Tags', 'Date'
  ];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#4285f4').setFontColor('white');

  // Data
  if (results.length > 0) {
    sheet.getRange(2, 1, results.length, headers.length).setValues(results);

    // Conditional formatting for risk scores
    const riskRange = sheet.getRange(2, 7, results.length, 1);
    applyRiskFormatting(riskRange);

    // Conditional formatting for priority
    const priorityRange = sheet.getRange(2, 6, results.length, 1);
    applyPriorityFormatting(priorityRange);
  }

  // Auto-resize columns
  sheet.autoResizeColumns(1, headers.length);

  Logger.log(`[OK] Updated Orders sheet: ${results.length} rows`);
}

/**
 * Update Interactions sheet with Q&A analytics
 */
function updateInteractionsSheet(ss) {
  const sheet = getOrCreateSheet(ss, 'Q&A Interactions');

  const query = `
    SELECT
      question,
      answer,
      top_similarity,
      timestamp
    FROM \`${PROJECT_ID}.${DATASET}.interactions\`
    WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    ORDER BY timestamp DESC
    LIMIT 50
  `;

  const results = runBigQueryQuery(query);

  sheet.clear();

  const headers = ['Question', 'Answer', 'Relevance', 'Time'];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#34a853').setFontColor('white');

  if (results.length > 0) {
    sheet.getRange(2, 1, results.length, headers.length).setValues(results);
  }

  sheet.autoResizeColumns(1, headers.length);

  Logger.log(`[OK] Updated Interactions sheet: ${results.length} rows`);
}

/**
 * Update Analytics sheet with summary metrics
 */
function updateAnalyticsSheet(ss) {
  const sheet = getOrCreateSheet(ss, 'Analytics');
  sheet.clear();

  // Daily order metrics
  const orderQuery = `
    SELECT
      DATE(created_at) as date,
      COUNT(*) as total_orders,
      SUM(total_amount) as revenue,
      AVG(ai_risk_score) as avg_risk,
      SUM(CASE WHEN ai_priority = 'high' THEN 1 ELSE 0 END) as high_priority
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY date
    ORDER BY date DESC
  `;

  const orderResults = runBigQueryQuery(orderQuery);

  // Write order metrics
  sheet.getRange('A1').setValue('DAILY ORDER METRICS').setFontWeight('bold').setFontSize(14);
  const orderHeaders = ['Date', 'Orders', 'Revenue', 'Avg Risk', 'High Priority'];
  sheet.getRange(2, 1, 1, orderHeaders.length).setValues([orderHeaders]);
  sheet.getRange(2, 1, 1, orderHeaders.length).setFontWeight('bold').setBackground('#fbbc04').setFontColor('white');

  if (orderResults.length > 0) {
    sheet.getRange(3, 1, orderResults.length, orderHeaders.length).setValues(orderResults);
  }

  // Interaction metrics
  const interactionQuery = `
    SELECT
      DATE(timestamp) as date,
      COUNT(*) as total_questions,
      AVG(top_similarity) as avg_relevance
    FROM \`${PROJECT_ID}.${DATASET}.interactions\`
    WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY date
    ORDER BY date DESC
  `;

  const interactionResults = runBigQueryQuery(interactionQuery);

  const startRow = orderResults.length + 5;
  sheet.getRange(startRow, 1).setValue('DAILY Q&A METRICS').setFontWeight('bold').setFontSize(14);
  const interactionHeaders = ['Date', 'Questions', 'Avg Relevance'];
  sheet.getRange(startRow + 1, 1, 1, interactionHeaders.length).setValues([interactionHeaders]);
  sheet.getRange(startRow + 1, 1, 1, interactionHeaders.length).setFontWeight('bold').setBackground('#ea4335').setFontColor('white');

  if (interactionResults.length > 0) {
    sheet.getRange(startRow + 2, 1, interactionResults.length, interactionHeaders.length).setValues(interactionResults);
  }

  sheet.autoResizeColumns(1, 5);

  Logger.log(`[OK] Updated Analytics sheet`);
}

/**
 * Update Alerts sheet with items needing attention
 */
function updateAlertsSheet(ss) {
  const sheet = getOrCreateSheet(ss, 'Alerts');
  sheet.clear();

  // High-risk orders
  const query = `
    SELECT
      '[ALERT] High Risk Order' as alert_type,
      order_number as reference,
      customer_email as details,
      ai_risk_score as score,
      created_at as time
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE ai_risk_score > 0.7
      AND DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

    UNION ALL

    SELECT
      '[WARNING] Fraud Flag' as alert_type,
      order_number as reference,
      ARRAY_TO_STRING(fraud_flags, ', ') as details,
      ai_risk_score as score,
      created_at as time
    FROM \`${PROJECT_ID}.${DATASET}.orders\`
    WHERE ARRAY_LENGTH(fraud_flags) > 0
      AND DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

    ORDER BY time DESC
    LIMIT 50
  `;

  const results = runBigQueryQuery(query);

  const headers = ['Alert Type', 'Reference', 'Details', 'Score', 'Time'];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#ea4335').setFontColor('white');

  if (results.length > 0) {
    sheet.getRange(2, 1, results.length, headers.length).setValues(results);
    // Highlight entire rows
    sheet.getRange(2, 1, results.length, headers.length).setBackground('#fce8e6');
  } else {
    sheet.getRange('A2').setValue('[OK] No alerts - all clear!');
  }

  sheet.autoResizeColumns(1, headers.length);

  Logger.log(`[OK] Updated Alerts sheet: ${results.length} alerts`);
}

/**
 * Run BigQuery query and return results as array
 */
function runBigQueryQuery(query) {
  const request = {
    query: query,
    useLegacySql: false
  };

  try {
    const queryResults = BigQuery.Jobs.query(request, PROJECT_ID);
    const rows = queryResults.rows || [];

    return rows.map(row => {
      return row.f.map(field => field.v);
    });

  } catch (error) {
    Logger.log(`[ERROR] BigQuery error: ${error}`);
    return [];
  }
}

/**
 * Get or create sheet by name
 */
function getOrCreateSheet(ss, name) {
  let sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
  }
  return sheet;
}

/**
 * Apply conditional formatting for risk scores
 */
function applyRiskFormatting(range) {
  const rules = range.getSheet().getConditionalFormatRules();

  // High risk (>0.7) = red
  const highRiskRule = SpreadsheetApp.newConditionalFormatRule()
    .whenNumberGreaterThan(0.7)
    .setBackground('#f4c7c3')
    .setRanges([range])
    .build();

  // Medium risk (0.4-0.7) = yellow
  const medRiskRule = SpreadsheetApp.newConditionalFormatRule()
    .whenNumberBetween(0.4, 0.7)
    .setBackground('#fff2cc')
    .setRanges([range])
    .build();

  // Low risk (<0.4) = green
  const lowRiskRule = SpreadsheetApp.newConditionalFormatRule()
    .whenNumberLessThan(0.4)
    .setBackground('#d9ead3')
    .setRanges([range])
    .build();

  rules.push(highRiskRule, medRiskRule, lowRiskRule);
  range.getSheet().setConditionalFormatRules(rules);
}

/**
 * Apply conditional formatting for priority
 */
function applyPriorityFormatting(range) {
  const rules = range.getSheet().getConditionalFormatRules();

  const highPriorityRule = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('high')
    .setBackground('#f4c7c3')
    .setRanges([range])
    .build();

  rules.push(highPriorityRule);
  range.getSheet().setConditionalFormatRules(rules);
}

/**
 * Send email notification with dashboard link
 */
function sendUpdateNotification() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const url = ss.getUrl();
  const recipient = Session.getActiveUser().getEmail();

  const subject = 'Daily Dashboard Update';
  const body = `
Your AI Workflow Dashboard has been updated!

View dashboard: ${url}

Summary:
- Recent Orders updated
- Q&A Interactions logged
- Analytics refreshed
- Alerts checked

Last update: ${new Date().toLocaleString()}
  `;

  // Only send if there are alerts
  const alertsSheet = ss.getSheetByName('Alerts');
  if (alertsSheet && alertsSheet.getLastRow() > 1) {
    MailApp.sendEmail(recipient, subject, body);
    Logger.log(`[INFO] Notification sent to ${recipient}`);
  }
}

/**
 * Create custom menu
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('Dashboard')
    .addItem('Update Now', 'updateDashboard')
    .addItem('Setup Trigger', 'setupTrigger')
    .addToUi();
}

/**
 * Setup daily trigger
 */
function setupTrigger() {
  // Delete existing triggers
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => ScriptApp.deleteTrigger(trigger));

  // Create daily trigger at 9am
  ScriptApp.newTrigger('updateDashboard')
    .timeBased()
    .atHour(9)
    .everyDays(1)
    .create();

  SpreadsheetApp.getUi().alert('[SUCCESS] Daily trigger set for 9:00 AM');
}
