/**
 * Template for the encounter testing page
 */

function encounterTemplate(users) {
  return `
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
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f8f8; }
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
            
            let resultsHtml = '<h3>Results</h3>';
            resultsHtml += '<p>' + data.message + '</p>';
            resultsHtml += '<p>Found ' + data.encounters + ' potential encounters</p>';
            
            if (data.encounterDetails && data.encounterDetails.length > 0) {
              resultsHtml += '<h4>Encounter Details</h4>';
              resultsHtml += '<table class="results-table">';
              resultsHtml += '<tr><th>Users</th><th>Location</th><th>Start Time</th><th>End Time</th><th>Duration (min)</th></tr>';
              
              data.encounters.forEach(encounter => {
                resultsHtml += '<tr>' + 
                  '<td>' + encounter.startTime + '</td>' +
                  '<td>' + encounter.endTime + '</td>' +
                  '<td>' + encounter.encounterDuration + '</td>' +
                  '<td>' + encounter.encounterLocation + '</td>' +
                '</tr>';
              });
              
              resultsHtml += '</table>';
              resultsHtml += '<p><a href="/view/encounters">View all encounters</a></p>';
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
}

<<<<<<< HEAD
module.exports = encounterTemplate; 
=======
module.exports = encounterTemplate; 
>>>>>>> 6d3b67ac13132399b7a4bb382d87ad84b79ad01a
