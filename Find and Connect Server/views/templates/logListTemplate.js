/**
 * Template for the log list page
 */

function logListTemplate(heardLogs, tellLogs, users, username, logType) {
  // Group logs by user if no user filter is applied
  let logsHtml = '';
  
  if (!username) {
    // Get unique usernames
    const usernames = new Set();
    heardLogs.forEach(log => usernames.add(log.username));
    tellLogs.forEach(log => usernames.add(log.username));
    
    // Display logs for each user
    for (const name of usernames) {
      const user = users.find(u => u.username === name) || { username: name };
      
      logsHtml += `
        <div class="user-section">
          <h2>User: ${name}</h2>`;
      
      // Display user's HeardLogs
      const userHeardLogs = heardLogs.filter(log => log.username === name);
      if (userHeardLogs.length > 0 && (!logType || logType === 'heardLog')) {
        logsHtml += `
          <h3>Heard Logs (${userHeardLogs.length})</h3>
          <table>
            <tr>
              <th>Filename</th>
              <th>Upload Date</th>
              <th>Processed</th>
              <th>View Content</th>
            </tr>`;
            
        userHeardLogs.forEach(log => {
          logsHtml += `
            <tr class="heard">
              <td>${log.filename}</td>
              <td>${new Date(log.uploadDate).toLocaleString()}</td>
              <td>${log.processed ? 'Yes' : 'No'}</td>
              <td>
                <a href="/view/log/${log._id}" target="_blank">View Content</a>
              </td>
            </tr>`;
        });
        
        logsHtml += `</table>`;
      }
      
      // Display user's TellLogs
      const userTellLogs = tellLogs.filter(log => log.username === name);
      if (userTellLogs.length > 0 && (!logType || logType === 'tellLog')) {
        logsHtml += `
          <h3>Tell Logs (${userTellLogs.length})</h3>
          <table>
            <tr>
              <th>Filename</th>
              <th>Upload Date</th>
              <th>Processed</th>
              <th>View Content</th>
            </tr>`;
            
        userTellLogs.forEach(log => {
          logsHtml += `
            <tr class="tell">
              <td>${log.filename}</td>
              <td>${new Date(log.uploadDate).toLocaleString()}</td>
              <td>${log.processed ? 'Yes' : 'No'}</td>
              <td>
                <a href="/view/log/${log._id}" target="_blank">View Content</a>
              </td>
            </tr>`;
        });
        
        logsHtml += `</table>`;
      }
      
      logsHtml += `</div>`;
    }
  } else {
    // Display logs for selected user
    const user = users.find(u => u.username === username) || { username };
    
    logsHtml += `<h2>Logs for ${user.username}</h2>`;
    
    // Display HeardLogs
    if (heardLogs.length > 0 && (!logType || logType === 'heardLog')) {
      logsHtml += `
        <h3>Heard Logs (${heardLogs.length})</h3>
        <table>
          <tr>
            <th>Filename</th>
            <th>Upload Date</th>
            <th>Processed</th>
            <th>View Content</th>
          </tr>`;
          
      heardLogs.forEach(log => {
        logsHtml += `
          <tr class="heard">
            <td>${log.filename}</td>
            <td>${new Date(log.uploadDate).toLocaleString()}</td>
            <td>${log.processed ? 'Yes' : 'No'}</td>
            <td>
              <a href="/view/log/${log._id}" target="_blank">View Content</a>
            </td>
          </tr>`;
      });
      
      logsHtml += `</table>`;
    }
    
    // Display TellLogs
    if (tellLogs.length > 0 && (!logType || logType === 'tellLog')) {
      logsHtml += `
        <h3>Tell Logs (${tellLogs.length})</h3>
        <table>
          <tr>
            <th>Filename</th>
            <th>Upload Date</th>
            <th>Processed</th>
            <th>View Content</th>
          </tr>`;
          
      tellLogs.forEach(log => {
        logsHtml += `
          <tr class="tell">
            <td>${log.filename}</td>
            <td>${new Date(log.uploadDate).toLocaleString()}</td>
            <td>${log.processed ? 'Yes' : 'No'}</td>
            <td>
              <a href="/view/log/${log._id}" target="_blank">View Content</a>
            </td>
          </tr>`;
      });
      
      logsHtml += `</table>`;
    }
  }

  return `
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
      </div>
      
      ${logsHtml}
      
      <p>Total HeardLogs: ${heardLogs.length}, Total TellLogs: ${tellLogs.length}</p>
    </body>
    </html>
  `;
}

module.exports = logListTemplate; 