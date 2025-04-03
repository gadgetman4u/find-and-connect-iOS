/**
 * Template for viewing the contents of a specific log
 */

const { formatFileSize, escapeHtml } = require('../utils');

function logViewTemplate(log, fileContents) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Log Content: ${log.filename}</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        h1, h2 { color: #333; }
        .log-meta { margin-bottom: 20px; background: #f5f5f5; padding: 10px; border-radius: 4px; }
        .log-meta span { display: block; margin-bottom: 5px; }
        pre { background: #f0f0f0; padding: 15px; border-radius: 4px; overflow-x: auto; white-space: pre-wrap; }
        .nav { margin-bottom: 20px; }
        .nav a { margin-right: 15px; }
        .highlight { background-color: #ffffcc; }
      </style>
    </head>
    <body>
      <div class="nav">
        <a href="/view/logs">Back to Logs</a>
      </div>
      
      <h1>Log Content: ${log.filename}</h1>
      
      <div class="log-meta">
        <span><strong>Type:</strong> ${log.logType}</span>
        <span><strong>User:</strong> ${log.username}</span>
        <span><strong>Upload Date:</strong> ${new Date(log.uploadDate).toLocaleString()}</span>
        <span><strong>Size:</strong> ${formatFileSize(log.size)}</span>
        <span><strong>Processed:</strong> ${log.processed ? 'Yes' : 'No'}</span>
      </div>
      
      <h2>File Contents</h2>
      <pre>${escapeHtml(fileContents)}</pre>
    </body>
    </html>
  `;
}

module.exports = logViewTemplate; 