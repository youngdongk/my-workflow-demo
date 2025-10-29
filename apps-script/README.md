# Google Apps Script - Automated Dashboard

Automatically pulls data from BigQuery and creates beautiful dashboards in Google Sheets.

## Setup

1. **Create a new Google Sheet**
   - Go to sheets.google.com
   - Create new spreadsheet
   - Name it "AI Workflow Dashboard"

2. **Open Apps Script Editor**
   - Extensions > Apps Script
   - Delete default code
   - Copy `Code.gs` content and paste

3. **Configure Project**
   - Update `PROJECT_ID` constant with your GCP project ID
   - Save the script (Ctrl/Cmd + S)

4. **Enable BigQuery API**
   - In Apps Script editor: Resources > Advanced Google Services
   - Enable "BigQuery API"
   - Click "Google Cloud Platform API Dashboard"
   - Enable "BigQuery API" in GCP Console

5. **Run Initial Setup**
   - In Apps Script: Run > Run function > `onOpen`
   - Authorize the script (grant permissions)
   - Refresh your Google Sheet
   - You should see "Dashboard" menu

6. **Update Dashboard**
   - Click "Dashboard" > "Update Now"
   - Wait for execution to complete
   - View your auto-generated sheets!

7. **Setup Daily Automation**
   - Click "Dashboard" > "Setup Trigger"
   - This creates a trigger to update daily at 9 AM

## What It Creates

The script creates and updates 5 sheets:

1. **Recent Orders** - Latest orders with AI analysis
2. **Q&A Interactions** - Slack bot questions and answers
3. **Analytics** - Summary metrics and trends
4. **Alerts** - High-risk orders and fraud flags
5. **Metadata** - Last update timestamp

## Features

- Auto-refresh data from BigQuery
- Color-coded risk scores and priorities
- Email notifications for alerts
- Scheduled daily updates
- Ready-to-use dashboard views

## Customization

Edit queries in the script to:
- Change date ranges (currently 7-30 days)
- Add more metrics
- Modify formatting
- Adjust alert thresholds

## Troubleshooting

**"Service invoked too many times"**
- Apps Script has daily quotas
- Reduce update frequency or data volume

**"BigQuery error"**
- Verify PROJECT_ID is correct
- Check BigQuery API is enabled
- Ensure tables exist in BigQuery

**No data showing**
- Run populate scripts first to add sample data
- Check dataset name matches ("knowledge_base")
