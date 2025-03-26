const express = require('express');
const router = express.Router();
const Log = require('../models/Log');

// HTML view for all logs
router.get('/logs', async (req, res) => {
  try {
    // Get filter parameter from query string
    const logType = req.query.type;
    
    // Build query based on filter
    const query = logType ? { logType } : {};
    
    const logs = await Log.find(query).sort({ uploadDate: -1 });
    
    // Generate HTML
    let html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Find and Connect Logs</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
          h1 { color: #333; }
          .filter { margin-bottom: 20px; }
          .filter a { margin-right: 15px; padding: 5px 10px; text-decoration: none; color: #333; border: 1px solid #ddd; border-radius: 4px; }
          .filter a.active { background-color: #4CAF50; color: white; border-color: #4CAF50; }
          table { width: 100%; border-collapse: collapse; }
          th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
          tr:hover { background-color: #f5f5f5; }
          .heard { background-color: #e6f7ff; }
          .tell { background-color: #f9f9e0; }
        </style>
      </head>
      <body>
        <h1>Uploaded Logs</h1>
        
        <div class="filter">
          <a href="/view/logs" ${!logType ? 'class="active"' : ''}>All Logs</a>
          <a href="/view/logs?type=heardLog" ${logType === 'heardLog' ? 'class="active"' : ''}>Heard Logs</a>
          <a href="/view/logs?type=tellLog" ${logType === 'tellLog' ? 'class="active"' : ''}>Tell Logs</a>
        </div>
        
        <table>
          <tr>
            <th>Filename</th>
            <th>Username</th>
            <th>Type</th>
            <th>Upload Date</th>
            <th>Processed</th>
          </tr>`;
    
    logs.forEach(log => {
      const rowClass = log.logType === 'heardLog' ? 'heard' : 'tell';
      html += `
        <tr class="${rowClass}">
          <td>${log.filename}</td>
          <td>${log.username}</td>
          <td>${log.logType}</td>
          <td>${new Date(log.uploadDate).toLocaleString()}</td>
          <td>${log.processed ? 'Yes' : 'No'}</td>
        </tr>`;
    });
    
    html += `
        </table>
        <p>Total logs: ${logs.length}</p>
      </body>
      </html>`;
    
    res.send(html);
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 