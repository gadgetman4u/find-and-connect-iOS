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

    // Create log document in the generic Log collection
    const log = new Log({
      filename: req.file.filename,
      originalName: req.file.originalname,
      path: req.file.path,
      size: req.file.size,
      username: username,
      logType
    });

    await log.save();
    
    // Also save to the specific collection based on type
    if (logType === 'heardLog') {
      const heardLog = new HeardLog({
        filename: req.file.filename,
        originalName: req.file.originalname,
        path: req.file.path,
        size: req.file.size,
        username: username,
      });
      await heardLog.save();
    } else {
      const tellLog = new TellLog({
        filename: req.file.filename,
        originalName: req.file.originalname,
        path: req.file.path,
        size: req.file.size,
        username: username
      });
      await tellLog.save();
    }
    
    res.status(201).json({
      message: 'File uploaded successfully',
      log: {
        id: log._id,
        filename: log.filename,
        originalName: log.originalName,
        size: log.size,
        username: log.username,
        logType: log.logType
      }
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

// Add this new test route
router.post('/test-upload', upload.single('file'), (req, res) => {
  console.log("Test upload route reached");
  console.log("Body:", req.body);
  console.log("File:", req.file);
  
  res.status(200).json({
    message: 'Test route working',
    body: req.body,
    file: req.file ? 'File received' : 'No file'
  });
});

// Delete a specific log by ID
router.delete('/delete/:id', async (req, res) => {
  try {
    const logId = req.params.id;
    
    // Find the log first to get the file path
    const log = await Log.findById(logId);
    
    if (!log) {
      return res.status(404).json({ message: 'Log not found' });
    }
    
    // Store the file path before deleting the log
    const filePath = log.path;
    
    // Delete from database
    await Log.findByIdAndDelete(logId);
    
    // Delete the physical file
    if (filePath && fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log(`Deleted file: ${filePath}`);
    }
    
    return res.status(200).json({ 
      message: 'Log and file deleted successfully',
      deletedLog: log
    });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete all logs for a specific user
router.delete('/delete/user/:username', async (req, res) => {
  try {
    const username = req.params.username;
    
    // Find all logs for this user first
    const logs = await Log.find({ username });
    
    // Delete physical files
    let filesDeleted = 0;
    for (const log of logs) {
      if (log.path && fs.existsSync(log.path)) {
        fs.unlinkSync(log.path);
        filesDeleted++;
      }
    }
    
    // Delete from database
    const result = await Log.deleteMany({ username });
    
    res.status(200).json({ 
      message: `Deleted ${result.deletedCount} logs and ${filesDeleted} files for user ${username}`,
      count: result.deletedCount,
      filesDeleted
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

module.exports = router; 