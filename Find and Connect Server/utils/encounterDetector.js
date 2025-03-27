const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const Log = require('../models/Log');
const Encounter = require('../models/Encounter');
const HeardLog = require('../models/HeardLog');
const TellLog = require('../models/TellLog');

// Path to the Python script
const PYTHON_SCRIPT = path.join(__dirname, '..', 'EncounterAlgorithm.py');

// Check if python3 or python is available
function getPythonCommand() {
  try {
    // Try python3 first
    const python3 = spawn('python3', ['--version']);
    return 'python3';
  } catch (error) {
    try {
      // Try python if python3 fails
      const python = spawn('python', ['--version']);
      return 'python';
    } catch (error) {
      console.error('Neither python3 nor python are available. Please install Python.');
      return null;
    }
  }
}

// Process logs to detect encounters
async function processLogs(logId, logType, targetUsername = null) {
  try {
    // Get the log that was just uploaded
    const log = await Log.findById(logId);
    if (!log) {
      console.error('Log not found:', logId);
      return 0;
    }

    console.log(`Processing ${logType} for user ${log.username}`);
    
    // Build the query for finding potential matching logs
    const query = {
      logType: logType === 'heardLog' ? 'tellLog' : 'heardLog', // Get opposite type logs
      username: { $ne: log.username }                           // Different user
    };
    
    // If a specific target user is provided, only check against that user's logs
    if (targetUsername) {
      query.username = targetUsername;
      console.log(`Targeting specific user: ${targetUsername}`);
    }
    
    // Find potential matching logs based on query
    const potentialMatches = await Log.find(query);
    console.log(`Found ${potentialMatches.length} potential matching logs`);
    
    // Process each potential match
    let encountersFound = 0;
    for (const otherLog of potentialMatches) {
      // Determine which is the heardLog and which is the tellLog
      const heardLog = logType === 'heardLog' ? log : otherLog;
      const tellLog = logType === 'tellLog' ? log : otherLog;
      
      // Check for encounters using the Python script
      const encounters = await checkForEncountersPython(heardLog, tellLog);
      encountersFound += encounters.length;
    }
    
    console.log(`Detection complete. Found ${encountersFound} encounters.`);
    
    // Mark log as processed
    log.processed = true;
    await log.save();
    
    return encountersFound;
  } catch (error) {
    console.error('Error processing logs:', error);
    return 0;
  }
}

// Check for encounters between two logs using Python script
async function checkForEncountersPython(heardLog, tellLog) {
  return new Promise((resolve, reject) => {
    try {
      const pythonCommand = getPythonCommand();
      if (!pythonCommand) {
        console.error('Python is not available. Cannot run encounter algorithm.');
        return resolve([]);
      }
      
      console.log(`Running Python script: ${pythonCommand} ${PYTHON_SCRIPT} ${heardLog.path} ${tellLog.path}`);
      
      // Spawn the Python process
      const pythonProcess = spawn(pythonCommand, [
        PYTHON_SCRIPT,
        heardLog.path,
        tellLog.path
      ]);
      
      let dataString = '';
      let errorString = '';
      
      // Collect data from the Python script
      pythonProcess.stdout.on('data', (data) => {
        dataString += data.toString();
      });
      
      // Collect any errors
      pythonProcess.stderr.on('data', (data) => {
        errorString += data.toString();
        console.error(`Python script error: ${data.toString()}`);
      });
      
      // Handle the end of process
      pythonProcess.on('close', async (code) => {
        if (code !== 0) {
          console.error(`Python script exited with code ${code}`);
          console.error(`Error output: ${errorString}`);
          return resolve([]);
        }
        
        try {
          // Parse the encounters from the JSON output
          const encounters = JSON.parse(dataString.trim());
          
          // Save encounters to database
          for (const encounter of encounters) {
            await saveEncounter(heardLog, tellLog, encounter);
          }
          
          resolve(encounters);
        } catch (error) {
          console.error('Error parsing Python script output:', error);
          console.error('Output was:', dataString);
          resolve([]);
        }
      });
    } catch (error) {
      console.error('Error running Python script:', error);
      resolve([]);
    }
  });
}

// Save encounter to database
async function saveEncounter(heardLog, tellLog, encounter) {
  try {
    // Create a new encounter record
    const newEncounter = new Encounter({
      user1: heardLog.username,
      user2: tellLog.username,
      heardLogId: heardLog._id,
      tellLogId: tellLog._id,
      location: encounter.location,
      timestamp: new Date(encounter.timestamp.replace(/-/g, '/')),
      confidence: encounter.confidence
    });

    // Save the encounter (ignoring duplicates)
    await newEncounter.save().catch(err => {
      if (err.code !== 11000) { // Not a duplicate error
        throw err;
      }
      console.log('Duplicate encounter detected, skipping');
    });

    console.log(`Encounter detected between ${heardLog.username} and ${tellLog.username} at ${encounter.location}`);
    return true;
  } catch (error) {
    console.error('Error saving encounter:', error);
    return false;
  }
}

module.exports = {
  processLogs,
  checkForEncountersPython
}; 