const express = require('express');
const router = express.Router();
const Log = require('../models/Log');
const User = require('../models/User');
const fs = require('fs');
const path = require('path');

// Add this at the beginning of your routes
router.get('/', (req, res) => {
  // Option 1: Redirect to the logs page
  res.redirect('/view/logs');
});

// HTML view for all logs
router.get('/logs', async (req, res) => {
  try {
    // Get filter parameters
    const username = req.query.username;
    const logType = req.query.type;
    
    let logs = [];
    
    // Build query based on filters
    if (username && logType) {
      logs = await Log.find({ 
        username: { $regex: new RegExp(`^${username}$`, 'i') },
        logType 
      }).sort({ uploadDate: -1 });
    } else if (username) {
      logs = await Log.find({ 
        username: { $regex: new RegExp(`^${username}$`, 'i') }
      }).sort({ uploadDate: -1 });
    } else if (logType) {
      logs = await Log.find({ logType }).sort({ uploadDate: -1 });
    } else {
      logs = await Log.find().sort({ uploadDate: -1 });
    }

    // Group logs by type for displaying
    const heardLogs = logs.filter(log => log.logType === 'heardLog');
    const tellLogs = logs.filter(log => log.logType === 'tellLog');
    
    // Get all users for display
    const users = await User.find().sort({ username: 1 });
    
    // Generate HTML
    let html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Find and Connect Logs</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
          h1, h2 { color: #333; }
          .filter { margin-bottom: 20px; }
          .filter a, .user-filter a { margin-right: 15px; padding: 5px 10px; text-decoration: none; color: #333; border: 1px solid #ddd; border-radius: 4px; }
          .filter a.active, .user-filter a.active { background-color: #4CAF50; color: white; border-color: #4CAF50; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
          th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
          tr:hover { background-color: #f5f5f5; }
          .heard { background-color: #e6f7ff; }
          .tell { background-color: #f9f9e0; }
          .user-section { margin-top: 30px; border-top: 2px solid #eee; padding-top: 20px; }
        </style>
      </head>
      <body>
        <h1>Find and Connect Logs</h1>
        
        <div class="filter">
          <a href="/view/logs" ${!logType ? 'class="active"' : ''}>All Logs</a>
          <a href="/view/logs?type=heardLog" ${logType === 'heardLog' ? 'class="active"' : ''}>Heard Logs</a>
          <a href="/view/logs?type=tellLog" ${logType === 'tellLog' ? 'class="active"' : ''}>Tell Logs</a>
          <a href="/view/encounters">Test Encounters</a>
          <a href="/view/test-python-algorithm">Test Python Algorithm</a>
        </div>
        
        <div class="user-filter">
          <strong>Filter by User:</strong>
          <a href="/view/logs" ${!username ? 'class="active"' : ''}>All Users</a>
          ${users.map(user => 
            `<a href="/view/logs?username=${user.username}" ${username?.toLowerCase() === user.username.toLowerCase() ? 'class="active"' : ''}>${user.username}</a>`
          ).join('')}
          
          <div style="margin-top: 10px; display: flex; align-items: center;">
            <form action="/view/logs" method="get" style="display: flex; align-items: center;">
              <input 
                type="text" 
                name="username" 
                placeholder="Enter username to filter" 
                value="${username || ''}"
                style="padding: 5px; margin-right: 10px; border: 1px solid #ddd; border-radius: 4px;"
              >
              <button 
                type="submit" 
                style="padding: 5px 10px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer;"
              >
                Filter
              </button>
              ${logType ? `<input type="hidden" name="type" value="${logType}">` : ''}
            </form>
            ${username ? 
              `<a href="${logType ? `/view/logs?type=${logType}` : '/view/logs'}" 
                style="margin-left: 10px; color: #666; text-decoration: none;"
              >
                Clear Filter
              </a>` 
              : ''
            }
          </div>
        </div>`;
    
    // Group logs by user if no user filter is applied
    if (!username) {
      // Get unique usernames
      const usernames = new Set();
      heardLogs.forEach(log => usernames.add(log.username));
      tellLogs.forEach(log => usernames.add(log.username));
      
      // Display logs for each user
      for (const name of usernames) {
        const user = users.find(u => u.username === name) || { username: name };
        
        html += `
          <div class="user-section">
            <h2>User: ${name}</h2>`;
        
        // Display user's HeardLogs
        const userHeardLogs = heardLogs.filter(log => log.username === name);
        if (userHeardLogs.length > 0 && (!logType || logType === 'heardLog')) {
          html += `
            <h3>Heard Logs (${userHeardLogs.length})</h3>
            <table>
              <tr>
                <th>Filename</th>
                <th>Upload Date</th>
                <th>Processed</th>
                <th>View Content</th>
              </tr>`;
              
          userHeardLogs.forEach(log => {
            html += `
              <tr class="heard">
                <td>${log.filename}</td>
                <td>${new Date(log.uploadDate).toLocaleString()}</td>
                <td>${log.processed ? 'Yes' : 'No'}</td>
                <td>
                  <a href="/view/log/${log._id}" target="_blank">View Content</a>
                </td>
              </tr>`;
          });
          
          html += `</table>`;
        }
        
        // Display user's TellLogs
        const userTellLogs = tellLogs.filter(log => log.username === name);
        if (userTellLogs.length > 0 && (!logType || logType === 'tellLog')) {
          html += `
            <h3>Tell Logs (${userTellLogs.length})</h3>
            <table>
              <tr>
                <th>Filename</th>
                <th>Upload Date</th>
                <th>Processed</th>
                <th>View Content</th>
              </tr>`;
              
          userTellLogs.forEach(log => {
            html += `
              <tr class="tell">
                <td>${log.filename}</td>
                <td>${new Date(log.uploadDate).toLocaleString()}</td>
                <td>${log.processed ? 'Yes' : 'No'}</td>
                <td>
                  <a href="/view/log/${log._id}" target="_blank">View Content</a>
                </td>
              </tr>`;
          });
          
          html += `</table>`;
        }
        
        html += `</div>`;
      }
    } else {
      // Display logs for selected user
      const user = users.find(u => u.username === username) || { username };
      
      html += `<h2>Logs for ${user.username}</h2>`;
      
      // Display HeardLogs
      if (heardLogs.length > 0 && (!logType || logType === 'heardLog')) {
        html += `
          <h3>Heard Logs (${heardLogs.length})</h3>
          <table>
            <tr>
              <th>Filename</th>
              <th>Upload Date</th>
              <th>Processed</th>
              <th>View Content</th>
            </tr>`;
            
        heardLogs.forEach(log => {
          html += `
            <tr class="heard">
              <td>${log.filename}</td>
              <td>${new Date(log.uploadDate).toLocaleString()}</td>
              <td>${log.processed ? 'Yes' : 'No'}</td>
              <td>
                <a href="/view/log/${log._id}" target="_blank">View Content</a>
              </td>
            </tr>`;
        });
        
        html += `</table>`;
      }
      
      // Display TellLogs
      if (tellLogs.length > 0 && (!logType || logType === 'tellLog')) {
        html += `
          <h3>Tell Logs (${tellLogs.length})</h3>
          <table>
            <tr>
              <th>Filename</th>
              <th>Upload Date</th>
              <th>Processed</th>
              <th>View Content</th>
            </tr>`;
            
        tellLogs.forEach(log => {
          html += `
            <tr class="tell">
              <td>${log.filename}</td>
              <td>${new Date(log.uploadDate).toLocaleString()}</td>
              <td>${log.processed ? 'Yes' : 'No'}</td>
              <td>
                <a href="/view/log/${log._id}" target="_blank">View Content</a>
              </td>
            </tr>`;
        });
        
        html += `</table>`;
      }
    }
    
    // Close HTML
    html += `
        <p>Total HeardLogs: ${heardLogs.length}, Total TellLogs: ${tellLogs.length}</p>
      </body>
      </html>`;
    
    res.send(html);
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).send('Server error');
  }
});

router.get('/encounters', async (req, res) => {
  try {
    // Get all users
    const users = await User.find().sort({ username: 1 });
    
    // Generate HTML form for testing encounters
    let html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Encounter Detection</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
          h1 { color: #333; }
          .form-group { margin-bottom: 15px; }
          label { display: block; margin-bottom: 5px; }
          select { width: 100%; padding: 8px; }
          button { padding: 10px 15px; background: #4CAF50; color: white; border: none; cursor: pointer; }
          .results { margin-top: 20px; padding: 15px; border: 1px solid #ddd; background: #f9f9f9; }
        </style>
      </head>
      <body>
        <h1>Test Encounter Detection</h1>
        
        <form id="encounterForm">
          <div class="form-group">
            <label>User:</label>
            <select id="username" name="username">
              <option value="">Select a user</option>
              ${users.map(user => `<option value="${user.username}">${user.username}</option>`).join('')}
            </select>
          </div>
          
          <div class="form-group">
            <label>Target User (Optional - leave blank to check against all users):</label>
            <select id="targetUsername" name="targetUsername">
              <option value="">All Users</option>
              ${users.map(user => `<option value="${user.username}">${user.username}</option>`).join('')}
            </select>
          </div>
          
          <button type="submit">Process Encounters</button>
        </form>
        
        <div id="results" class="results" style="display: none;"></div>
        
        <script>
          document.getElementById('encounterForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const targetUsername = document.getElementById('targetUsername').value;
            
            if (!username) {
              alert('Please select a user');
              return;
            }
            
            const resultsDiv = document.getElementById('results');
            resultsDiv.innerHTML = 'Processing...';
            resultsDiv.style.display = 'block';
            
            try {
              const response = await fetch('/api/logs/process-encounters', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                  username, 
                  targetUsername: targetUsername || undefined 
                })
              });
              
              const data = await response.json();
              
              resultsDiv.innerHTML = 
                '<h3>Results</h3>' +
                '<p>' + data.message + '</p>' +
                '<p>Found ' + data.encounters + ' potential encounters</p>';
            } catch (error) {
              resultsDiv.innerHTML = '<p>Error: ' + (error.message || 'Unknown error') + '</p>';
            }
          });
        </script>
      </body>
      </html>
    `;
    
    res.send(html);
  } catch (error) {
    console.error('Error loading encounter test page:', error);
    res.status(500).send('Server error');
  }
});

// Add a route to view contents of a specific log
router.get('/log/:id', async (req, res) => {
  try {
    const logId = req.params.id;
    const log = await Log.findById(logId);
    
    if (!log) {
      return res.status(404).send('Log not found');
    }
    
    // Check if file exists
    if (!fs.existsSync(log.path)) {
      return res.status(404).send('Log file not found on server');
    }
    
    // Read the file contents
    const fileContents = fs.readFileSync(log.path, 'utf8');
    
    // Generate HTML
    let html = `
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
    
    res.send(html);
  } catch (error) {
    console.error('Error viewing log content:', error);
    res.status(500).send('Server error');
  }
});

// Add a route to test the Python algorithm
router.get('/test-python-algorithm', async (req, res) => {
  try {
    // Get all logs
    const heardLogs = await Log.find({ logType: 'heardLog' }).sort({ uploadDate: -1 });
    const tellLogs = await Log.find({ logType: 'tellLog' }).sort({ uploadDate: -1 });
    
    // Generate HTML form for testing Python algorithm
    let html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Python Encounter Algorithm</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
          h1 { color: #333; }
          .form-group { margin-bottom: 15px; }
          label { display: block; margin-bottom: 5px; }
          select { width: 100%; padding: 8px; }
          button { padding: 10px 15px; background: #4CAF50; color: white; border: none; cursor: pointer; }
          .results { margin-top: 20px; padding: 15px; border: 1px solid #ddd; background: #f9f9f9; }
          pre { background: #f0f0f0; padding: 10px; border-radius: 4px; overflow-x: auto; }
        </style>
      </head>
      <body>
        <h1>Test Python Encounter Algorithm</h1>
        
        <form id="algorithmForm">
          <div class="form-group">
            <label>HeardLog:</label>
            <select id="heardLogId" name="heardLogId">
              <option value="">Select a HeardLog</option>
              ${heardLogs.map(log => `<option value="${log._id}">${log.filename} (${log.username})</option>`).join('')}
            </select>
          </div>
          
          <div class="form-group">
            <label>TellLog:</label>
            <select id="tellLogId" name="tellLogId">
              <option value="">Select a TellLog</option>
              ${tellLogs.map(log => `<option value="${log._id}">${log.filename} (${log.username})</option>`).join('')}
            </select>
          </div>
          
          <button type="submit">Run Python Algorithm</button>
        </form>
        
        <div id="results" class="results" style="display: none;"></div>
        
        <script>
          document.getElementById('algorithmForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const heardLogId = document.getElementById('heardLogId').value;
            const tellLogId = document.getElementById('tellLogId').value;
            
            if (!heardLogId || !tellLogId) {
              alert('Please select both a HeardLog and a TellLog');
              return;
            }
            
            const resultsDiv = document.getElementById('results');
            resultsDiv.innerHTML = 'Processing with Python algorithm...';
            resultsDiv.style.display = 'block';
            
            try {
              const response = await fetch('/api/logs/test-python-algorithm', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                  heardLogId, 
                  tellLogId
                })
              });
              
              const data = await response.json();
              
              let resultsHtml = '<h3>Results</h3>';
              resultsHtml += '<p>Found ' + data.total + ' potential encounters</p>';
              
              if (data.encounters && data.encounters.length > 0) {
                resultsHtml += '<pre>' + JSON.stringify(data.encounters, null, 2) + '</pre>';
              } else {
                resultsHtml += '<p>No encounters detected.</p>';
              }
              
              resultsDiv.innerHTML = resultsHtml;
            } catch (error) {
              resultsDiv.innerHTML = '<p>Error: ' + (error.message || 'Unknown error') + '</p>';
            }
          });
        </script>
      </body>
      </html>
    `;
    
    res.send(html);
  } catch (error) {
    console.error('Error loading Python algorithm test page:', error);
    res.status(500).send('Server error');
  }
});

// Helper function to format file size
function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' bytes';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// Helper function to escape HTML to prevent XSS
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = router; 