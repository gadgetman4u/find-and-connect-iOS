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

//Upload log file without processing encounters
router.post('/upload', upload.single('file'), async (req, res) => {
  console.log("==== LOG UPLOAD ROUTE REACHED ====");
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
      console.log(`Creating new user: ${username}`);
      user = new User({
        username,
        email,   // Add email to new user
        encounters: []
      });
    } else if (email && (!user.email || user.email !== email)) {
      // Update email if provided and different from existing
      user.email = email;
    }
    
    // Update the appropriate log field
    if (logType === 'heardLog') {
      user.heardLog = log;
    } else {
      user.tellLog = log;
    }
    
    // Save user - with better error handling
    try {
      const savedUser = await user.save();
      console.log(`Successfully saved/updated user: ${username}`);
    } catch (userError) {
      console.error('Error saving user:', userError);
      // Continue processing but report the error
      return res.status(500).json({ 
        message: 'Log uploaded but failed to update user record',
        error: userError.toString(),
        log,
        logId: log._id,
        success: false
      });
    }
    
    // Create type-specific log document
    if (logType === 'heardLog') {
      const heardLog = new HeardLog({
        logId: log._id,
      });
      await heardLog.save();
    } else {
      const tellLog = new TellLog({
        logId: log._id,
      });
      await tellLog.save();
    }

    // Return the log info without processing encounters
    res.status(201).json({
      message: `Log uploaded successfully. Ready for encounter processing.`,
      log,
      logId: log._id,
      success: true
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.toString(),
      stack: error.stack,
      success: false 
    });
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

// Process all encounters for a specific user (comprehensive approach)
router.post('/process-encounters/:username', async (req, res) => {
  try {
    console.log("==== PROCESS ALL ENCOUNTERS ROUTE REACHED ====");
    
    const { username } = req.params;
    console.log(`Processing all encounters for user: ${username}`);
    
    // Find user's logs of both types
    const userLogs = await Logs.find({ username });
    
    if (userLogs.length === 0) {
      return res.status(404).json({ 
        message: `No logs found for user ${username}`, 
        success: false 
      });
    }
    
    // Separate logs by type
    const heardLogs = userLogs.filter(log => log.logType === 'heardLog');
    const tellLogs = userLogs.filter(log => log.logType === 'tellLog');
    
    console.log(`Found ${heardLogs.length} heard logs and ${tellLogs.length} tell logs for ${username}`);
    
    // Find all other users with logs
    const otherUsersWithLogs = await Logs.distinct('username', { username: { $ne: username } });
    console.log(`Found ${otherUsersWithLogs.length} other users with logs to compare against`);
    
    let allEncounters = [];
    let savedEncountersCount = 0;
    let processedUsers = [];
    
    // Process user's heard logs against other users' tell logs
    for (const heardLog of heardLogs) {
      // Get all tell logs from other users
      const otherUsersTellLogs = await Logs.find({ 
        username: { $ne: username },
        logType: 'tellLog'
      });
      
      console.log(`Processing ${username}'s heard log against ${otherUsersTellLogs.length} tell logs from other users`);
      
      for (const tellLog of otherUsersTellLogs) {
        // Detect encounters
        const userEncounters = await detectEncounters(heardLog, tellLog);
        
        // If encounters were found, process them
        if (userEncounters && userEncounters.length > 0) {
          processedUsers.push({
            username: tellLog.username,
            encounters: userEncounters.length
          });
          
          // Save each encounter with better duplicate checking
          for (const encounter of userEncounters) {
            try {
              // Get time values for overlap checking
              const encounterStart = new Date(encounter.startTime);
              const encounterEnd = new Date(encounter.endTime);
              
              // Check for overlapping encounters with same users
              const user1 = encounter.user1;
              const user2 = encounter.user2;
              
              // Consistent ordering of users for the query
              const [queryUser1, queryUser2] = [user1, user2].sort();
              
              // Find any existing encounters between these users with overlapping time
              const existingEncounters = await Encounter.find({
                $or: [
                  { $and: [{ user1: queryUser1 }, { user2: queryUser2 }] },
                  { $and: [{ user1: queryUser2 }, { user2: queryUser1 }] }
                ]
              });
              
              // Check for overlaps
              let hasOverlap = false;
              for (const existing of existingEncounters) {
                const existingStart = new Date(existing.startTime);
                const existingEnd = new Date(existing.endTime);
                
                // Check for time overlap
                if (
                  (encounterStart <= existingEnd && encounterEnd >= existingStart) || 
                  (existingStart <= encounterEnd && existingEnd >= encounterStart)
                ) {
                  hasOverlap = true;
                  break;
                }
              }
              
              if (!hasOverlap) {
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
              } else {
                console.log(`Skipping encounter between ${encounter.user1} and ${encounter.user2} at ${encounter.startTime} due to overlap with existing record`);
              }
            } catch (error) {
              console.error('Error saving encounter:', error);
            }
          }
          
          // Add to all encounters
          allEncounters = [...allEncounters, ...userEncounters];
        }
      }
      
      // Mark heard log as processed
      heardLog.processed = true;
      await heardLog.save();
    }
    
    // Process user's tell logs against other users' heard logs
    for (const tellLog of tellLogs) {
      // Get all heard logs from other users
      const otherUsersHeardLogs = await Logs.find({ 
        username: { $ne: username },
        logType: 'heardLog'
      });
      
      console.log(`Processing ${username}'s tell log against ${otherUsersHeardLogs.length} heard logs from other users`);
      
      for (const heardLog of otherUsersHeardLogs) {
        // Detect encounters (heardLog first, tellLog second in the function call)
        const userEncounters = await detectEncounters(heardLog, tellLog);
        
        // If encounters were found, process them
        if (userEncounters && userEncounters.length > 0) {
          processedUsers.push({
            username: heardLog.username,
            encounters: userEncounters.length
          });
          
          // Save each encounter with better duplicate checking
          for (const encounter of userEncounters) {
            try {
              // Get time values for overlap checking
              const encounterStart = new Date(encounter.startTime);
              const encounterEnd = new Date(encounter.endTime);
              
              // Check for overlapping encounters with same users
              const user1 = encounter.user1;
              const user2 = encounter.user2;
              
              // Consistent ordering of users for the query
              const [queryUser1, queryUser2] = [user1, user2].sort();
              
              // Find any existing encounters between these users with overlapping time
              const existingEncounters = await Encounter.find({
                $or: [
                  { $and: [{ user1: queryUser1 }, { user2: queryUser2 }] },
                  { $and: [{ user1: queryUser2 }, { user2: queryUser1 }] }
                ]
              });
              
              // Check for overlaps
              let hasOverlap = false;
              for (const existing of existingEncounters) {
                const existingStart = new Date(existing.startTime);
                const existingEnd = new Date(existing.endTime);
                
                // Check for time overlap
                if (
                  (encounterStart <= existingEnd && encounterEnd >= existingStart) || 
                  (existingStart <= encounterEnd && existingEnd >= encounterStart)
                ) {
                  hasOverlap = true;
                  break;
                }
              }
              
              if (!hasOverlap) {
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
              } else {
                console.log(`Skipping encounter between ${encounter.user1} and ${encounter.user2} at ${encounter.startTime} due to overlap with existing record`);
              }
            } catch (error) {
              console.error('Error saving encounter:', error);
            }
          }
          
          // Add to all encounters
          allEncounters = [...allEncounters, ...userEncounters];
        }
      }
      
      // Mark tell log as processed
      tellLog.processed = true;
      await tellLog.save();
    }
    
    // Sync encounters for the user
    await syncUserEncounters(username);
    
    // Sync for all other processed users
    const uniqueProcessedUsers = [...new Set(processedUsers.map(u => u.username))];
    console.log(`Syncing encounters for ${uniqueProcessedUsers.length} other users`);
    
    for (const otherUsername of uniqueProcessedUsers) {
      await syncUserEncounters(otherUsername);
    }
    
    // Get the updated user with encounters
    const updatedUser = await User.findOne({ username }).lean();
    
    // Return detailed results
    return res.status(200).json({
      message: `Processing complete for user ${username}`,
      success: true,
      encountersDetected: allEncounters.length,
      encountersSavedToDatabase: savedEncountersCount,
      encountersAfterDeduplication: updatedUser ? updatedUser.encounters.length : 0,
      explanation: "Detected encounters come from log analysis, saved encounters are new ones added to database, and deduplicated encounters are what appears in user profile after merging overlaps.",
      processedLogs: {
        heardLogs: heardLogs.length,
        tellLogs: tellLogs.length
      },
      processedWithUsers: uniqueProcessedUsers,
      userEncounters: updatedUser ? updatedUser.encounters : []
    });
    
  } catch (error) {
    console.error('Error in comprehensive encounter processing:', error);
    res.status(500).json({ 
      message: 'Server error during encounter processing', 
      error: error.message,
      success: false
    });
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


// Process encounters for all user logs (batch processing)
router.post('/process-user-encounters', async (req, res) => {
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

module.exports = router; 