/**
 * Routes for listing logs
 */

const express = require('express');
const router = express.Router();
const Log = require('../../models/Log');
const User = require('../../models/User');
const logListTemplate = require('../templates/logListTemplate');

// HTML view for all logs
router.get('/logs', async (req, res) => {
  try {
    // Get filter parameters
    const username = req.query.username;
    const logType = req.query.type;
    
    let logs = [];
    
    // Build query based on filters
    if (username && logType) {
      logs = await Log.find({ 
        username: { $regex: new RegExp(`^${username}$`, 'i') },
        logType 
      }).sort({ uploadDate: -1 });
    } else if (username) {
      logs = await Log.find({ 
        username: { $regex: new RegExp(`^${username}$`, 'i') }
      }).sort({ uploadDate: -1 });
    } else if (logType) {
      logs = await Log.find({ logType }).sort({ uploadDate: -1 });
    } else {
      logs = await Log.find().sort({ uploadDate: -1 });
    }

    // Group logs by type for displaying
    const heardLogs = logs.filter(log => log.logType === 'heardLog');
    const tellLogs = logs.filter(log => log.logType === 'tellLog');
    
    // Get all users for display
    const users = await User.find().sort({ username: 1 });
    
    // Generate HTML using template
    const html = logListTemplate(heardLogs, tellLogs, users, username, logType);
    
    res.send(html);
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 