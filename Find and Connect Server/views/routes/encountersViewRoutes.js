/**
 * Routes for viewing encounters in HTML
 */

const express = require('express');
const router = express.Router();
const Encounter = require('../../models/Encounter');
const encountersTemplate = require('../templates/encountersTemplate');

// View all encounters
router.get('/encounters', async (req, res) => {
  try {
    const encounters = await Encounter.find()
      .sort({ detectionDate: -1 });
    
    const html = encountersTemplate(encounters);
    res.send(html);
  } catch (error) {
    console.error('Error fetching encounters:', error);
    res.status(500).send('Server error');
  }
});

// View encounters for a specific user
router.get('/encounters/user/:username', async (req, res) => {
  try {
    const username = req.params.username;
    
    const encounters = await Encounter.find({
      $or: [
        { user1: username },
        { user2: username }
      ]
    }).sort({ startTime: -1 });
    
    const html = encountersTemplate(encounters, username);
    res.send(html);
  } catch (error) {
    console.error('Error fetching user encounters:', error);
    res.status(500).send('Server error');
  }
});

// View encounters between two users
router.get('/encounters/between/:user1/:user2', async (req, res) => {
  try {
    const { user1, user2 } = req.params;
    
    const encounters = await Encounter.find({
      $or: [
        { user1, user2 },
        { user1: user2, user2: user1 }
      ]
    }).sort({ startTime: -1 });
    
    const html = encountersTemplate(encounters, `${user1} and ${user2}`);
    res.send(html);
  } catch (error) {
    console.error('Error fetching encounters between users:', error);
    res.status(500).send('Server error');
  }
});

module.exports = router; 