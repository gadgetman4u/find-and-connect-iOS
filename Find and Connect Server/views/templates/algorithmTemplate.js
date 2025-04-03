/**
 * Template for the Python algorithm testing page
 */

function algorithmTemplate(heardLogs, tellLogs) {
  return `
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
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f8f8; }
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
              resultsHtml += '<table class="results-table">';
              resultsHtml += '<tr><th>Start Time</th><th>End Time</th><th>Duration (min)</th><th>Location</th></tr>';
              
              data.encounters.forEach(encounter => {
                resultsHtml += '<tr>' + 
                  '<td>' + encounter.startTime + '</td>' +
                  '<td>' + encounter.endTime + '</td>' +
                  '<td>' + encounter.encounterDuration + '</td>' +
                  '<td>' + encounter.encounterLocation + '</td>' +
                '</tr>';
              });
              
              resultsHtml += '</table>';
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
}

module.exports = algorithmTemplate; 