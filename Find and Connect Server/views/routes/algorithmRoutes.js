/**
 * Routes for testing the Python algorithm
 */

const express = require('express');
const router = express.Router();
const Log = require('../../models/Log');
const algorithmTemplate = require('../templates/algorithmTemplate');

// Route for Python algorithm testing
router.get('/test-python-algorithm', async (req, res) => {
  try {
    // Get all logs
    const heardLogs = await Log.find({ logType: 'heardLog' }).sort({ uploadDate: -1 });
    const tellLogs = await Log.find({ logType: 'tellLog' }).sort({ uploadDate: -1 });
    
    // Generate HTML using template
    const html = algorithmTemplate(heardLogs, tellLogs);
    
    res.send(html);
  } catch (error) {
    console.error('Error loading Python algorithm test page:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 