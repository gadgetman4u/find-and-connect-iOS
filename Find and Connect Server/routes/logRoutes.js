const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload');
const { Logs } = require('../models/Log');
const HeardLog = require('../models/HeardLog');
const TellLog = require('../models/TellLog');
const path = require('path');
const fs = require('fs');
const { processLogs, detectEncounters, syncUserEncounters } = require('../utils/encounterDetector');
const { Encounter } = require('../models/Encounter');
const User = require('../models/User');

// Create a reusable function for log deletion
async function deleteUserLogs(username, logType) {
  // Find all logs matching criteria
  const logs = await Logs.find({ username, logType }).sort({ uploadDate: -1 });
  
  console.log(`Found ${logs.length} logs for ${username} of type ${logType}`);
  
  // Delete physical files and associated records
  let filesDeleted = 0;
  for (const log of logs) {
    if (log.path) {
      // Check if the path is already absolute
      const filePath = path.isAbsolute(log.path) 
        ? log.path 
        : path.join(__dirname, '..', log.path);
      
      console.log(`Attempting to delete file: ${filePath}`);
      
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        console.log(`Deleted file: ${filePath}`);
        filesDeleted++;
      } else {
        console.log(`File not found: ${filePath}`);
      }
    }
    
    // Delete type-specific entries
    if (logType === 'heardLog') {
      const deleted = await HeardLog.deleteMany({ logId: log._id });
      console.log(`Deleted ${deleted.deletedCount} HeardLog entries`);
    } else {
      const deleted = await TellLog.deleteMany({ logId: log._id });
      console.log(`Deleted ${deleted.deletedCount} TellLog entries`);
    }
    
    // Also delete any encounters that used this log
    if (logType === 'heardLog') {
      const deleted = await Encounter.deleteMany({ heardLogId: log._id });
      console.log(`Deleted ${deleted.deletedCount} encounters with this HeardLog`);
    } else {
      const deleted = await Encounter.deleteMany({ tellLogId: log._id });
      console.log(`Deleted ${deleted.deletedCount} encounters with this TellLog`);
    }
  }
  
  // Delete from database
  const result = await Logs.deleteMany({ username, logType });
  console.log(`Deleted ${result.deletedCount} logs from the main Log collection`);
  
  return {
    count: result.deletedCount,
    filesDeleted
  };
}

// Create a handler function that can be called internally or via the API
async function deleteUserLogsHandler(username, logType) {
  return await deleteUserLogs(username, logType);
}

//Upload log file
router.post('/upload', upload.single('file'), async (req, res) => {
  console.log("==== ROUTE REACHED ====");
  console.log("Body:", JSON.stringify(req.body, null, 2));
  console.log("File:", req.file ? "Present" : "Missing");
  
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    // Get user type and log type from request
    const { username, logType, email } = req.body;
    
    if (!username || !logType) {
      return res.status(400).json({ message: 'Username and log type are required' });
    }
    
    if (logType !== 'heardLog' && logType !== 'tellLog') {
      return res.status(400).json({ message: 'Log type must be heardLog or tellLog' });
    }

    // Check if the user already has a log of this type
    const existingLog = await Logs.findOne({ username, logType });
    
    if (existingLog) {
      console.log(`User ${username} already has a ${logType}, deleting it.`);
      
      // Call the delete function directly
      await deleteUserLogsHandler(username, logType);
      console.log(`Deleted existing ${logType} for ${username}`);
    }

    // Create log document in the generic Log collection
    const log = new Logs({
      filename: req.file.filename,
      originalName: req.file.originalname,
      path: req.file.path,
      size: req.file.size,
      username,
      email,
      logType,
      processed: false
    });

    // Save to database
    await log.save();
    
    // Find or create User document - no userId needed, will use MongoDB's _id
    let user = await User.findOne({ username });
    
    // If user doesn't exist, create a new one
    if (!user) {
      user = new User({
        username,
        encounters: []
      });
    }
    
    // Update the appropriate log field
    if (logType === 'heardLog') {
      user.heardLog = log;
    } else {
      user.tellLog = log;
    }
    
    // Save user - handle potential errors with a cleaner approach
    try {
      await user.save();
    } catch (error) {
      console.error('Error saving user:', error.message);
      // Continue with the process even if user save fails
      // We'll at least have the log saved
    }
    
    // Create type-specific log document
    if (logType === 'heardLog') {
      const heardLog = new HeardLog({
        logId: log._id,
        // Add any heard-specific fields here
      });
      await heardLog.save();
    } else {
      const tellLog = new TellLog({
        logId: log._id,
        // Add any tell-specific fields here
      });
      await tellLog.save();
    }

    // Process logs to find and save encounters
    let encounters = [];
    let savedEncountersCount = 0;
    let otherUsersData = [];
    
    // Find users with opposite log type
    const oppositeLogType = logType === 'heardLog' ? 'tellLog' : 'heardLog';
    const otherUsers = await Logs.find({ 
      username: { $ne: username },
      logType: oppositeLogType 
    });
    
    console.log(`Found ${otherUsers.length} users with ${oppositeLogType} logs to check against`);
    
    // For each user with the opposite log type
    for (const otherLog of otherUsers) {
      // First detect encounters between the new log and this user's opposite type log
      const userEncounters = logType === 'heardLog' 
        ? await detectEncounters(log, otherLog)
        : await detectEncounters(otherLog, log);
      
      // If encounters were found, add the user's data
      if (userEncounters && userEncounters.length > 0) {
        otherUsersData.push({
          username: otherLog.username,
          email: otherLog.email,
          encounters: userEncounters.length
        });
        
        // Now save each encounter to the database
        for (const encounter of userEncounters) {
          try {
            // Check if encounter already exists
            const existingEncounter = await Encounter.findOne({
              user1: encounter.user1,
              user2: encounter.user2,
              startTime: encounter.startTime,
              endTime: encounter.endTime
            });
            
            if (!existingEncounter) {
              // Create a new encounter record
              const newEncounter = new Encounter({
                user1: encounter.user1,
                user2: encounter.user2,
                startTime: encounter.startTime,
                endTime: encounter.endTime,
                encounterLocation: encounter.encounterLocation,
                encounterDuration: encounter.encounterDuration
              });
              
              await newEncounter.save();
              savedEncountersCount++;
            }
          } catch (error) {
            console.error('Error saving encounter:', error);
          }
        }
      }
      
      // Add these encounters to our results for display
      encounters = [...encounters, ...userEncounters];
    }
    
    // Mark the log as processed
    log.processed = true;
    await log.save();
    
    // Sync encounters to users
    if (savedEncountersCount > 0) {
      console.log(`Saved ${savedEncountersCount} encounters, syncing with users...`);
      await syncUserEncounters(username);
      
      // Sync with other users who had encounters
      for (const userData of otherUsersData) {
        await syncUserEncounters(userData.username);
      }
    }
    
    // Return the log and encounters directly
    res.status(201).json({
      message: `Log uploaded successfully. Found ${encounters.length} potential encounters, saved ${savedEncountersCount}.`,
      log,
      encounters,
      otherUsers: otherUsersData
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get logs by user ID
router.get('/user/:username', async (req, res) => {
  try {
    const logs = await Logs.find({ username: req.params.username }).sort({ uploadDate: -1 });
    res.status(200).json({ logs });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all logs
router.get('/', async (req, res) => {
  try {
    const logs = await Logs.find().sort({ uploadDate: -1 });
    res.status(200).json({ logs });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});


// Delete logs for a specific user AND logType
router.delete('/delete/user/:username/:logType', async (req, res) => {
  try {
    const { username, logType } = req.params;
    
    if (logType !== 'heardLog' && logType !== 'tellLog') {
      return res.status(400).json({ message: 'Log type must be heardLog or tellLog' });
    }
    
    const result = await deleteUserLogsHandler(username, logType);
    
    res.status(200).json({
      message: `Deleted ${result.count} ${logType}s and ${result.filesDeleted} files for user ${username}`,
      count: result.count,
      filesDeleted: result.filesDeleted
    });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete all logs of a specific type
router.delete('/delete/type/:logType', async (req, res) => {
  try {
    const logType = req.params.logType;
    
    if (logType !== 'heardLog' && logType !== 'tellLog') {
      return res.status(400).json({ message: 'Log type must be heardLog or tellLog' });
    }
    
    // Find all logs of this type first
    const logs = await Logs.find({ logType });
    
    // Delete physical files
    let filesDeleted = 0;
    for (const log of logs) {
      if (log.path && fs.existsSync(log.path)) {
        fs.unlinkSync(log.path);
        filesDeleted++;
      }
    }
    
    // Delete from database
    const result = await Logs.deleteMany({ logType });
    
    res.status(200).json({ 
      message: `Deleted ${result.deletedCount} ${logType}s and ${filesDeleted} files`,
      count: result.deletedCount,
      filesDeleted
    });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete all logs
router.delete('/delete/all', async (req, res) => {
  try {
    // Find all logs first
    const logs = await Logs.find({});
    
    // Delete physical files
    let filesDeleted = 0;
    for (const log of logs) {
      if (log.path && fs.existsSync(log.path)) {
        fs.unlinkSync(log.path);
        filesDeleted++;
      }
    }
    
    // Delete from database
    const result = await Logs.deleteMany({});
    
    res.status(200).json({ 
      message: `Deleted ${result.deletedCount} logs and ${filesDeleted} files`,
      count: result.deletedCount,
      filesDeleted
    });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Process encounters for a user
router.post('/process-encounters', async (req, res) => {
  try {
    const { username, targetUsername } = req.body;
    
    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }
    
    // Find logs for this user
    const logs = await Logs.find({ username });
    
    if (logs.length === 0) {
      return res.status(404).json({ message: 'No logs found for this user', encounters: 0 });
    }
    
    // Process each log
    let totalEncounters = 0;
    let encounterDetails = []; // To store encounter details
    
    for (const log of logs) {
      const encounters = await processLogs(log._id, log.logType, targetUsername);
      totalEncounters += encounters;
      
      // If encounters were found, get their details
      if (encounters > 0) {
        const details = await Encounter.find({
          $or: [
            { user1: username },
            { user2: username }
          ]
        }).sort({ detectionDate: -1 }).limit(10); // Get the most recent 10 
        
        encounterDetails = details;
      }
    }
    
    // Return the encounter count and details
    return res.status(200).json({ 
      message: `Processed ${logs.length} logs for ${username}`,
      encounters: totalEncounters,
      encounterDetails
    });
  } catch (error) {
    console.error('Error processing encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Test Python encounter algorithm
router.post('/test-python-algorithm', async (req, res) => {
  try {
    const { heardLogId, tellLogId } = req.body;
    
    if (!heardLogId || !tellLogId) {
      return res.status(400).json({ message: 'Both heardLogId and tellLogId are required' });
    }
    
    // Get logs
    const heardLog = await Logs.findById(heardLogId);
    const tellLog = await Logs.findById(tellLogId);
    
    if (!heardLog || !tellLog) {
      return res.status(404).json({ message: 'One or both logs not found' });
    }
    
    // Check for encounters using Python
    const { checkForEncountersPython } = require('../utils/encounterDetector');
    const encounters = await checkForEncountersPython(heardLog, tellLog);
    
    res.status(200).json({
      message: 'Python algorithm test completed',
      encounters: encounters,
      total: encounters.length
    });
  } catch (error) {
    console.error('Python algorithm test error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router; 