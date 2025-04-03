/**
 * Routes for viewing individual log contents
 */

const express = require('express');
const router = express.Router();
const Log = require('../../models/Log');
const fs = require('fs');
const logViewTemplate = require('../templates/logViewTemplate');

// View the content of a specific log
router.get('/log/:id', async (req, res) => {
  try {
    const logId = req.params.id;
    const log = await Log.findById(logId);
    
    if (!log) {
      return res.status(404).send('Log not found');
    }
    
    // Check if file exists
    if (!fs.existsSync(log.path)) {
      return res.status(404).send('Log file not found on server');
    }
    
    // Read the file contents
    const fileContents = fs.readFileSync(log.path, 'utf8');
    
    // Generate HTML using template
    const html = logViewTemplate(log, fileContents);
    
    res.send(html);
  } catch (error) {
    console.error('Error viewing log content:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 