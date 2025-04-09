const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const Log = require('../models/Log');
const Encounter = require('../models/Encounter');
const HeardLog = require('../models/HeardLog');
const TellLog = require('../models/TellLog');

// Path to the Python script
const PYTHON_SCRIPT = path.join(__dirname, '..', 'python', 'EncounterAlgorithm.py');

// Execute Python script with arguments
const executePython = async (script, args) => {
  const arguments = args.map(arg => arg.toString());

  const python = spawn('python3', [script, ...arguments]);

  const result = await new Promise((resolve, reject) => {
    let dataString = '';

    python.stdout.on('data', (data) => {
      dataString += data.toString();
    });

    python.stderr.on('data', (data) => {
      console.error(`Python script error: ${data}`);
      reject(data);
    });

    python.on("exit", (code) => {
      if (code !== 0) {
        reject(new Error(`Python script exited with code ${code}`));
      } else {
        try {
          // Parse the complete output string
          resolve(JSON.parse(dataString));
        } catch (error) {
          console.error('Failed to parse Python output:', dataString);
          reject(new Error('Failed to parse Python output'));
        }
      }
    });
  });

  return result;
};

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
    // Get the log from the main Log collection
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
    
    if(potentialMatches.length == 0) {
      console.log("No matching logs, returning")
      return 0;
    }

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
  try {
    console.log(`Running Python script: ${PYTHON_SCRIPT} with logs: ${heardLog.path} ${tellLog.path}`);
    
    // Use the executePython function
    const encounters = await executePython(PYTHON_SCRIPT, [
      '--max-idle', '3',
      '--min-duration', '3',
      '--heard-log', heardLog.path,
      '--tell-log', tellLog.path
    ]);
    
    // Save encounters to database
    if (Array.isArray(encounters)) {
      for (const encounter of encounters) {
        // Map Python output format to expected format
        const mappedEncounter = {
          startTime: encounter.startTime,
          endTime: encounter.endTime,
          encounterLocation: encounter.encounterLocation,
          encounterDuration: encounter.encounterDuration 
        };
        await saveEncounter(heardLog, tellLog, mappedEncounter);
      }
    }
    
    return Array.isArray(encounters) ? encounters : [];
  } catch (error) {
    console.error('Error running Python script:', error);
    return [];
  }
}

// Save encounter to database
async function saveEncounter(heardLog, tellLog, encounter) {
  try {
    console.log('Saving encounter:', encounter);
    console.log('Between users:', heardLog.username, 'and', tellLog.username);
    
    // Check if encounter already exists
    const existingEncounter = await Encounter.findOne({
      user1: heardLog.username,
      user2: tellLog.username,
      startTime: encounter.startTime,
      endTime: encounter.endTime
    });
    
    if (existingEncounter) {
      console.log('Encounter already exists, skipping');
      return false;
    }
    
    // Create a new encounter record with the updated schema
    const newEncounter = new Encounter({
      user1: heardLog.username,
      user2: tellLog.username,
      startTime: encounter.startTime,
      endTime: encounter.endTime,
      encounterLocation: encounter.encounterLocation,
      encounterDuration: encounter.encounterDuration,
    });
    
    console.log('New encounter object:', newEncounter);
    await newEncounter.save();
    console.log('Encounter saved successfully');
    return true;
  } catch (error) {
    console.error('Error saving encounter:', error);
    return false;
  }
}

// Create a new function that just processes and returns encounters without saving
async function detectEncounters(heardLog, tellLog) {
  try {
    console.log(`Running Python script: ${PYTHON_SCRIPT} with logs: ${heardLog.path} ${tellLog.path}`);
    
    // Execute the Python script with arguments
    const pythonResult = await executePython(PYTHON_SCRIPT, [
      '--max-idle', '3',
      '--min-duration', '1',
      '--heard-log', heardLog.path,
      '--tell-log', tellLog.path
    ]);
    
    // Safely handle different return types
    const encounters = Array.isArray(pythonResult) ? pythonResult : [];
    
    // Now safely map over the encounters array
    const processedEncounters = encounters.map(encounter => ({
      user1: heardLog.username,
      user2: tellLog.username,
      startTime: encounter.startTime,
      endTime: encounter.endTime,
      encounterLocation: encounter.encounterLocation,
      encounterDuration: encounter.encounterDuration
    }));
    
    console.log(`Detection complete. Found ${processedEncounters.length} encounters.`);
    
    return processedEncounters;
  } catch (error) {
    console.error('Error running Python script:', error);
    return [];
  }
}

// Export the new function
module.exports = {
  processLogs,         // Keep the old function for compatibility
  detectEncounters,    // Add the new function that doesn't save to DB
  checkForEncountersPython
}; 
