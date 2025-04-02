const express = require('express');
const router = express.Router();
const Encounter = require('../models/Encounter');
const Log = require('../models/Log');
const { processLogs } = require('../utils/encounterDetector');

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

// Get encounters for a specific user (with auto-processing)
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Clean the userId (remove colon if present)
    const cleanUserId = userId.startsWith(':') ? userId.substring(1) : userId;
    
    console.log(`Processing encounters for user ${cleanUserId} against all others...`);
    
    // Find all other users who have logs (exclude current user)
    const otherUsers = await Log.distinct('username', { username: { $ne: cleanUserId } });
    console.log(`Found ${otherUsers.length} other users with logs`);
    
    // Process logs against each other user
    let newEncountersCount = 0;
    
    // Get this user's logs
    const userHeardLogs = await Log.find({ username: cleanUserId, logType: 'heardLog' });
    const userTellLogs = await Log.find({ username: cleanUserId, logType: 'tellLog' });
    
    console.log(`User has ${userHeardLogs.length} heardLogs and ${userTellLogs.length} tellLogs`);
    
    for (const otherUser of otherUsers) {
      // Get other user's logs
      const otherHeardLogs = await Log.find({ username: otherUser, logType: 'heardLog' });
      const otherTellLogs = await Log.find({ username: otherUser, logType: 'tellLog' });
      
      // Process user's heardLogs against other user's tellLogs
      for (const log of userHeardLogs) {
        const encounters = await processLogs(log._id, 'heardLog', otherUser);
        newEncountersCount += encounters;
      }
      
      // Process user's tellLogs against other user's heardLogs
      for (const log of userTellLogs) {
        const encounters = await processLogs(log._id, 'tellLog', otherUser);
        newEncountersCount += encounters;
      }
    }
    
    console.log(`Processed ${newEncountersCount} new encounters`);
    
    // Now fetch all encounters for this user (including newly processed ones)
    console.log(`Looking for encounters with user1=${cleanUserId} OR user2=${cleanUserId}`);

    const encounters = await Encounter.find({
      $or: [
        { user1: cleanUserId },
        { user2: cleanUserId }
      ]
    }).sort({ startTime: -1 });

    console.log(`Found ${encounters.length} encounters in database:`, encounters);
    
    res.status(200).json({ 
      message: `Found ${encounters.length} encounters for user ${cleanUserId} (including ${newEncountersCount} newly processed)`,
      encounters 
    });
  } catch (error) {
    console.error('Error fetching user encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});


module.exports = router; 