const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { Logs } = require('../models/Log');
const { Encounter } = require('../models/Encounter');
const HeardLog = require('../models/HeardLog');
const TellLog = require('../models/TellLog');
const User = require('../models/User');

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
    const log = await Logs.findById(logId);
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
    const potentialMatches = await Logs.find(query);
    console.log(`Found ${potentialMatches.length} potential matching logs`);
    
    if(potentialMatches.length == 0) {
      console.log("No matching logs, returning")
      return 0;
    }

    // Process each potential match
    let encountersFound = 0;
    let usersToSync = new Set([log.username]);
    
    for (const otherLog of potentialMatches) {
      // Determine which is the heardLog and which is the tellLog
      const heardLog = logType === 'heardLog' ? log : otherLog;
      const tellLog = logType === 'tellLog' ? log : otherLog;
      
      // Check for encounters using the Python script
      const encounters = await checkForEncountersPython(heardLog, tellLog);
      encountersFound += encounters.length;
      
      // Add other user to sync list if encounters were found
      if (encounters.length > 0) {
        usersToSync.add(otherLog.username);
      }
    }
    
    console.log(`Detection complete. Found ${encountersFound} encounters.`);
    
    // Mark log as processed
    log.processed = true;
    await log.save();
    
    // Sync encounters for all affected users
    console.log(`Syncing encounters for ${usersToSync.size} users`);
    for (const username of usersToSync) {
      await syncUserEncounters(username);
    }
    
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
    
    // Sync encounters to user documents
    await syncUserEncounters(heardLog.username);
    await syncUserEncounters(tellLog.username);
    
    return true;
  } catch (error) {
    console.error('Error saving encounter:', error);
    return false;
  }
}

// Sync standalone encounters with user documents
async function syncUserEncounters(username) {
  try {
    console.log(`Syncing encounters for user: ${username}`);
    
    // Get all encounters for this user
    const encounters = await Encounter.find({
      $or: [{ user1: username }, { user2: username }]
    });
    
    console.log(`Found ${encounters.length} encounters for user ${username}`);
    
    // Find the user
    const user = await User.findOne({ username });
    if (!user) {
      console.error(`User ${username} not found for encounter sync`);
      return false;
    }
    
    // Deduplicate encounters by removing time overlaps
    const deduplicatedEncounters = deduplicateEncounters(encounters);
    console.log(`Deduplicated to ${deduplicatedEncounters.length} encounters from ${encounters.length}`);
    
    // Convert standalone encounters to embedded format
    const embeddedEncounters = deduplicatedEncounters.map(encounter => ({
      user1: encounter.user1,
      user2: encounter.user2,
      startTime: encounter.startTime,
      endTime: encounter.endTime,
      encounterLocation: encounter.encounterLocation,
      encounterDuration: encounter.encounterDuration
    }));
    
    // Update the user's encounters array
    user.encounters = embeddedEncounters;
    await user.save();
    console.log(`Updated user ${username} with ${embeddedEncounters.length} encounters`);
    
    return true;
  } catch (error) {
    console.error('Error syncing user encounters:', error);
    return false;
  }
}

// Helper function to deduplicate encounters by removing overlapping time periods
function deduplicateEncounters(encounters) {
  // Group encounters by unique user pairs
  const groupedEncounters = {};
  
  // Sort encounters by startTime for each pair
  encounters.forEach(encounter => {
    // Ensure consistent ordering of user1 and user2 for grouping
    const users = [encounter.user1, encounter.user2].sort();
    const pairKey = `${users[0]}_${users[1]}`;
    
    if (!groupedEncounters[pairKey]) {
      groupedEncounters[pairKey] = [];
    }
    
    const startTime = new Date(encounter.startTime);
    const endTime = new Date(encounter.endTime);
    
    groupedEncounters[pairKey].push({
      encounter,
      startTime,
      endTime
    });
  });
  
  // Process each group to remove overlaps
  const result = [];
  
  Object.entries(groupedEncounters).forEach(([pairKey, encounters]) => {
    console.log(`Deduplicating ${encounters.length} encounters for user pair: ${pairKey}`);
    
    // Sort by start time
    encounters.sort((a, b) => a.startTime - b.startTime);
    
    // Process encounters to merge overlapping ones
    const merged = [];
    let current = null;
    
    encounters.forEach(item => {
      if (!current) {
        current = item;
        return;
      }
      
      // Check for overlap
      if (item.startTime <= current.endTime) {
        console.log(`Found overlapping encounters: ${current.encounter.startTime} - ${current.encounter.endTime} overlaps with ${item.encounter.startTime} - ${item.encounter.endTime}`);
        
        // Merge by taking later end time
        if (item.endTime > current.endTime) {
          console.log(`Extending encounter end time from ${current.encounter.endTime} to ${item.encounter.endTime}`);
          current.endTime = item.endTime;
          
          // Update duration
          const durationMinutes = Math.round((current.endTime - current.startTime) / (1000 * 60));
          current.encounter.encounterDuration = durationMinutes;
          current.encounter.endTime = item.encounter.endTime;
        }
      } else {
        // No overlap, add current to results and set new current
        merged.push(current.encounter);
        current = item;
      }
    });
    
    // Add the last item
    if (current) {
      merged.push(current.encounter);
    }
    
    console.log(`Deduplicated from ${encounters.length} to ${merged.length} encounters for pair ${pairKey}`);
    result.push(...merged);
  });
  
  return result;
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
  checkForEncountersPython,
  syncUserEncounters   // Export the new sync function
}; 
