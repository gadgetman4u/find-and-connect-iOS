const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload');
const Log = require('../models/Log');
const path = require('path');
const fs = require('fs');
const { processLogs } = require('../utils/encounterDetector');

// Upload log file
router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    // Get user ID and log type from request
    const { userId, username, logType } = req.body;
    
    if (!userId || !logType || !username) {
      return res.status(400).json({ message: 'User ID, username, and log type are required' });
    }
    
    if (logType !== 'heardLog' && logType !== 'tellLog') {
      return res.status(400).json({ message: 'Log type must be heardLog or tellLog' });
    }

    // Create new log document in MongoDB
    const log = new Log({
      filename: req.file.filename,
      originalName: req.file.originalname,
      path: req.file.path,
      size: req.file.size,
      userId,
      username,
      logType
    });

    await log.save();
    
    // Trigger encounter detection in the background
    processLogs(log._id);
    
    res.status(201).json({
      message: 'File uploaded successfully',
      log: {
        id: log._id,
        filename: log.filename,
        originalName: log.originalName,
        size: log.size,
        userId: log.userId,
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
router.get('/user/:userId', async (req, res) => {
  try {
    const logs = await Log.find({ userId: req.params.userId }).sort({ uploadDate: -1 });
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

module.exports = router; 