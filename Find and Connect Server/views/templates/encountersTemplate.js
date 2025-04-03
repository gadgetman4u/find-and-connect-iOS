/**
 * Template for viewing encounter records
 */

function encountersTemplate(encounters, filterUser = null) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>${filterUser ? `Encounters for ${filterUser}` : 'All Encounters'}</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        h1, h2 { color: #333; }
        .filter { margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f8f8; }
        tr:hover { background-color: #f5f5f5; }
        .nav { margin-bottom: 20px; }
        .nav a { margin-right: 15px; }
        .user-filter { margin: 15px 0; }
        .user-filter a { margin-right: 10px; padding: 5px 8px; text-decoration: none; border: 1px solid #ddd; border-radius: 3px; }
        .user-filter a.active { background-color: #4CAF50; color: white; }
      </style>
    </head>
    <body>
      <div class="nav">
        <a href="/view/logs">Logs</a>
        <a href="/view/test-python-algorithm">Test Algorithm</a>
      </div>
      
      <h1>${filterUser ? `Encounters for ${filterUser}` : 'All Encounters'}</h1>
      
      ${filterUser ? 
        `<p><a href="/view/encounters">View all encounters</a></p>` : 
        `<div class="user-filter">
          <strong>Filter by user:</strong>
          <a href="/view/encounters" class="active">All</a>
          ${[...new Set(encounters.map(e => e.user1).concat(encounters.map(e => e.user2)))].map(user => 
            `<a href="/view/encounters/user/${user}">${user}</a>`
          ).join('')}
        </div>`
      }
      
      ${encounters.length === 0 ? 
        '<p>No encounters found.</p>' : 
        `<table>
          <tr>
            <th>User 1</th>
            <th>User 2</th>
            <th>Location</th>
            <th>Start Time</th>
            <th>End Time</th>
            <th>Duration (min)</th>
            <th>Detected On</th>
            <th>Actions</th>
          </tr>
          ${encounters.map(encounter => `
            <tr>
              <td>${encounter.user1}</td>
              <td>${encounter.user2}</td>
              <td>${encounter.location}</td>
              <td>${new Date(encounter.startTime).toLocaleString()}</td>
              <td>${new Date(encounter.endTime).toLocaleString()}</td>
              <td>${encounter.duration}</td>
              <td>${new Date(encounter.detectionDate).toLocaleString()}</td>
              <td>
                <a href="/view/encounters/detail/${encounter._id}">Details</a>
              </td>
            </tr>
          `).join('')}
        </table>`
      }
    </body>
    </html>
  `;
}

module.exports = encountersTemplate; 