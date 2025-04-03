const express = require('express');
const router = express.Router();
const Encounter = require('../models/Encounter');
const Log = require('../models/Log');
const { processLogs, detectEncounters } = require('../utils/encounterDetector');

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

// Get encounters for a specific user (on-demand processing)
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const cleanUserId = userId.startsWith(':') ? userId.substring(1) : userId;
    
    console.log(`On-demand processing for user ${cleanUserId}`);
    
    // Get this user's logs
    const userHeardLogs = await Log.find({ username: cleanUserId, logType: 'heardLog' });
    const userTellLogs = await Log.find({ username: cleanUserId, logType: 'tellLog' });
    
    // Get all other users
    const otherUsers = await Log.find({ username: { $ne: cleanUserId } });
    
    // Process each combination
    let allEncounters = [];
    
    // Process user's heardLogs against other users' tellLogs
    for (const heardLog of userHeardLogs) {
      for (const otherUser of otherUsers) {
        const tellLogs = await Log.find({ 
          username: otherUser.username, 
          logType: 'tellLog' 
        });
        
        for (const tellLog of tellLogs) {
          const encounters = await detectEncounters(heardLog, tellLog);
          allEncounters = [...allEncounters, ...encounters];
        }
      }
    }
    
    // Process other users' heardLogs against user's tellLogs
    for (const tellLog of userTellLogs) {
      for (const otherUser of otherUsers) {
        const heardLogs = await Log.find({ 
          username: otherUser.username, 
          logType: 'heardLog' 
        });
        
        for (const heardLog of heardLogs) {
          const encounters = await detectEncounters(heardLog, tellLog);
          allEncounters = [...allEncounters, ...encounters];
        }
      }
    }
    
    res.status(200).json({
      message: `Found ${allEncounters.length} potential encounters for user ${cleanUserId}`,
      encounters: allEncounters
    });
  } catch (error) {
    console.error('Error processing encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Add this temporary route to clear all encounters
router.delete('/reset', async (req, res) => {
  try {
    // Delete all encounters
    const result = await Encounter.deleteMany({});
    
    res.status(200).json({ 
      message: `Successfully deleted ${result.deletedCount} encounters`,
      count: result.deletedCount
    });
  } catch (error) {
    console.error('Error deleting encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router; 