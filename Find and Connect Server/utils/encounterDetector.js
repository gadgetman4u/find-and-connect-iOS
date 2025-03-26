const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const Log = require('../models/Log');
const Encounter = require('../models/Encounter');

// Process logs to detect encounters
async function processLogs(newLogId) {
  try {
    const newLog = await Log.findById(newLogId);
    if (!newLog) {
      console.error('Log not found:', newLogId);
      return;
    }

    // Find matching logs for encounter detection
    const oppositeLogType = newLog.logType === 'heardLog' ? 'tellLog' : 'heardLog';
    const otherLogs = await Log.find({
      userId: { $ne: newLog.userId },  // Different user
      logType: oppositeLogType        // Opposite log type
    });

    for (const otherLog of otherLogs) {
      const heardLog = newLog.logType === 'heardLog' ? newLog : otherLog;
      const tellLog = newLog.logType === 'tellLog' ? newLog : otherLog;
      
      // Check for encounters
      await checkForEncounters(heardLog, tellLog);
    }

    // Mark log as processed
    newLog.processed = true;
    await newLog.save();
    
  } catch (error) {
    console.error('Error processing logs:', error);
  }
}

// Check for encounters between two logs
async function checkForEncounters(heardLog, tellLog) {
  try {
    // Read log files
    const heardLogContent = fs.readFileSync(heardLog.path, 'utf8');
    const tellLogContent = fs.readFileSync(tellLog.path, 'utf8');

    // Parse logs and check for matching EIDs
    const heardEntries = parseHeardLog(heardLogContent);
    const tellEntries = parseTellLog(tellLogContent);
    
    // Find matching entries (encounters)
    const encounters = detectEncounters(heardEntries, tellEntries);
    
    // Save encounters to database
    for (const encounter of encounters) {
      await saveEncounter(heardLog, tellLog, encounter);
    }
    
    return encounters;
  } catch (error) {
    console.error('Error checking for encounters:', error);
    return [];
  }
}

// Parse heard log content into structured data
function parseHeardLog(content) {
  const entries = [];
  const lines = content.split('\n');
  
  for (const line of lines) {
    if (!line.trim()) continue;
    
    // Example format: "EID: abc123, Location: DPI_2038, RSSI: -65, Time: 2023-05-12-14:30:45, Username: John"
    const match = line.match(/EID: (.+), Location: (.+), RSSI: (.+), Time: (.+), Username: (.+)/);
    
    if (match) {
      const [_, eid, location, rssi, timestamp, username] = match;
      entries.push({
        eid,
        location,
        rssi,
        timestamp,
        username
      });
    }
  }
  
  return entries;
}

// Parse tell log content into structured data
function parseTellLog(content) {
  const entries = [];
  const lines = content.split('\n');
  
  for (const line of lines) {
    if (!line.trim()) continue;
    
    // Example format: "EID: abc123, Location: DPI_2038, Time: 2023-05-12-14:30:45, Username: John"
    const match = line.match(/EID: (.+), Location: (.+), Time: (.+), Username: (.+)/);
    
    if (match) {
      const [_, eid, location, timestamp, username] = match;
      entries.push({
        eid,
        location,
        timestamp,
        username
      });
    }
  }
  
  return entries;
}

// Detect encounters by matching EIDs and timestamps
function detectEncounters(heardEntries, tellEntries) {
  const encounters = [];
  const timeThreshold = 5 * 60 * 1000; // 5 minutes in milliseconds
  
  for (const heard of heardEntries) {
    for (const tell of tellEntries) {
      // Match EIDs
      if (heard.eid === tell.eid) {
        // Check if timestamps are close
        const heardTime = new Date(heard.timestamp.replace(/-/g, '/'));
        const tellTime = new Date(tell.timestamp.replace(/-/g, '/'));
        const timeDiff = Math.abs(heardTime.getTime() - tellTime.getTime());
        
        if (timeDiff <= timeThreshold) {
          encounters.push({
            eid: heard.eid,
            location: heard.location,
            timestamp: heardTime,
            heardUsername: heard.username,
            tellUsername: tell.username,
            confidence: 1.0 - (timeDiff / timeThreshold)  // Higher confidence for closer timestamps
          });
        }
      }
    }
  }
  
  return encounters;
}

// Save encounter to database
async function saveEncounter(heardLog, tellLog, encounter) {
  try {
    // Create a new encounter record
    const newEncounter = new Encounter({
      user1: heardLog.userId,
      user2: tellLog.userId,
      heardLogId: heardLog._id,
      tellLogId: tellLog._id,
      location: encounter.location,
      timestamp: encounter.timestamp,
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
  checkForEncounters
}; 