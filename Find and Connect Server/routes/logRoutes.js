const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload');
const Log = require('../models/Log');
const HeardLog = require('../models/HeardLog');
const TellLog = require('../models/TellLog');
const path = require('path');
const fs = require('fs');
const { processLogs } = require('../utils/encounterDetector');
const Encounter = require('../models/Encounter');

// Create a reusable function for log deletion
async function deleteUserLogs(username, logType) {
  // Find all logs matching criteria
  const logs = await Log.find({ username, logType }).sort({ uploadDate: -1 });
  
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
  const result = await Log.deleteMany({ username, logType });
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
    const { username, logType } = req.body;
    
    if (!username || !logType) {
      return res.status(400).json({ message: 'Username and log type are required' });
    }
    
    if (logType !== 'heardLog' && logType !== 'tellLog') {
      return res.status(400).json({ message: 'Log type must be heardLog or tellLog' });
    }

    // Check if the user already has a log of this type
    const existingLog = await Log.findOne({ username, logType });
    
    if (existingLog) {
      console.log(`User ${username} already has a ${logType}, deleting it.`);
      
      // Call the delete function directly
      await deleteUserLogsHandler(username, logType);
      console.log(`Deleted existing ${logType} for ${username}`);
    }

    // Create log document in the generic Log collection
    const log = new Log({
      filename: req.file.filename,
      originalName: req.file.originalname,
      path: req.file.path,
      size: req.file.size,
      username,
      logType,
      processed: false
    });

    // Save to database
    await log.save();
    
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

    res.status(201).json({
      message: 'Log uploaded successfully',
      log
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get logs by user ID
router.get('/user/:username', async (req, res) => {
  try {
    const logs = await Log.find({ username: req.params.username }).sort({ uploadDate: -1 });
    res.status(200).json({ logs });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all logs
router.get('/', async (req, res) => {
  try {
    const logs = await Log.find().sort({ uploadDate: -1 });
    res.status(200).json({ logs });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Download log file
router.get('/download/:id', async (req, res) => {
  try {
    const log = await Log.findById(req.params.id);
    
    if (!log) {
      return res.status(404).json({ message: 'Log not found' });
    }
    
    const filePath = path.resolve(log.path);
    
    // Check if file exists
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ message: 'File not found on server' });
    }
    
    res.download(filePath, log.originalName);
  } catch (error) {
    console.error('Download error:', error);
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
    const logs = await Log.find({ logType });
    
    // Delete physical files
    let filesDeleted = 0;
    for (const log of logs) {
      if (log.path && fs.existsSync(log.path)) {
        fs.unlinkSync(log.path);
        filesDeleted++;
      }
    }
    
    // Delete from database
    const result = await Log.deleteMany({ logType });
    
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
    const logs = await Log.find({});
    
    // Delete physical files
    let filesDeleted = 0;
    for (const log of logs) {
      if (log.path && fs.existsSync(log.path)) {
        fs.unlinkSync(log.path);
        filesDeleted++;
      }
    }
    
    // Delete from database
    const result = await Log.deleteMany({});
    
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
    const logs = await Log.find({ username });
    
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
    const heardLog = await Log.findById(heardLogId);
    const tellLog = await Log.findById(tellLogId);
    
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

// Add a cleanup route to fix inconsistencies
router.post('/cleanup-logs', async (req, res) => {
  try {
    // 1. Find all HeardLogs and TellLogs with invalid logId references
    const heardLogIds = await Log.find({ logType: 'heardLog' }).distinct('_id');
    const tellLogIds = await Log.find({ logType: 'tellLog' }).distinct('_id');
    
    const deleteHeardResult = await HeardLog.deleteMany({ 
      logId: { $nin: heardLogIds } 
    });
    
    const deleteTellResult = await TellLog.deleteMany({ 
      logId: { $nin: tellLogIds } 
    });
    
    // 2. Make sure there's only one HeardLog and one TellLog per user
    const users = await Log.distinct('username');
    let userCleaned = 0;
    
    for (const user of users) {
      // For each log type, keep only the newest one
      for (const logType of ['heardLog', 'tellLog']) {
        const logs = await Log.find({ username: user, logType }).sort({ uploadDate: -1 });
        
        if (logs.length > 1) {
          // Keep the first one (newest), delete the rest
          for (let i = 1; i < logs.length; i++) {
            // Delete file
            if (logs[i].path && fs.existsSync(logs[i].path)) {
              fs.unlinkSync(logs[i].path);
            }
            
            // Delete type-specific entry
            if (logType === 'heardLog') {
              await HeardLog.deleteMany({ logId: logs[i]._id });
            } else {
              await TellLog.deleteMany({ logId: logs[i]._id });
            }
            
            // Delete log entry
            await Log.findByIdAndDelete(logs[i]._id);
          }
          userCleaned++;
        }
      }
    }
    
    res.status(200).json({
      message: 'Database cleaned successfully',
      heardLogsRemoved: deleteHeardResult.deletedCount,
      tellLogsRemoved: deleteTellResult.deletedCount,
      usersCleaned: userCleaned
    });
  } catch (error) {
    console.error('Cleanup error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router; 