/**
 * Routes for testing encounter detection
 */

const express = require('express');
const router = express.Router();
const User = require('../../models/User');
const encounterTemplate = require('../templates/encounterTemplate');

// Route for encounter detection testing
router.get('/encounters', async (req, res) => {
  try {
    // Get all users
    const users = await User.find().sort({ username: 1 });
    
    // Generate HTML using template
    const html = encounterTemplate(users);
    
    res.send(html);
  } catch (error) {
    console.error('Error loading encounter test page:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 