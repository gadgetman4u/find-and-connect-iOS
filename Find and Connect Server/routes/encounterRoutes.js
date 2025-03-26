const express = require('express');
const router = express.Router();
const Encounter = require('../models/Encounter');

// Get all encounters
router.get('/', async (req, res) => {
  try {
    const encounters = await Encounter.find()
      .sort({ detectionDate: -1 });
    
    res.status(200).json({ encounters });
  } catch (error) {
    console.error('Error fetching encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get encounters for a specific user
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    
    const encounters = await Encounter.find({
      $or: [
        { user1: userId },
        { user2: userId }
      ]
    })
    .sort({ timestamp: -1 });
    
    res.status(200).json({ encounters });
  } catch (error) {
    console.error('Error fetching user encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get encounters between two specific users
router.get('/between/:user1Id/:user2Id', async (req, res) => {
  try {
    const { user1Id, user2Id } = req.params;
    
    const encounters = await Encounter.find({
      $or: [
        { user1: user1Id, user2: user2Id },
        { user1: user2Id, user2: user1Id }
      ]
    })
    .sort({ timestamp: -1 });
    
    res.status(200).json({ encounters });
  } catch (error) {
    console.error('Error fetching encounters between users:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router; 