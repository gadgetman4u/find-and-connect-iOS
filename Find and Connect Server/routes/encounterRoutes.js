const express = require('express');
const router = express.Router();
const { Encounter } = require('../models/Encounter');
const { Logs } = require('../models/Log');
const { processLogs, detectEncounters, syncUserEncounters } = require('../utils/encounterDetector');
const User = require('../models/User');

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
    const userHeardLogs = await Logs.find({ username: cleanUserId, logType: 'heardLog' });
    const userTellLogs = await Logs.find({ username: cleanUserId, logType: 'tellLog' });
    
    // Get all other users
    const otherUsers = await Logs.find({ username: { $ne: cleanUserId } });
    
    // Process each combination
    let allEncounters = [];
    
    // Process user's heardLogs against other users' tellLogs
    for (const heardLog of userHeardLogs) {
      for (const otherUser of otherUsers) {
        const tellLogs = await Logs.find({ 
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
        const heardLogs = await Logs.find({ 
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

// Add a route to sync encounters for a user
router.post('/sync/:username', async (req, res) => {
  try {
    const { username } = req.params;
    
    // Check if user exists
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Sync encounters
    const result = await syncUserEncounters(username);
    
    if (result) {
      // Get the updated user to return the encounter count
      const updatedUser = await User.findOne({ username });
      return res.status(200).json({
        message: `Successfully synced encounters for user ${username}`,
        encounterCount: updatedUser.encounters.length
      });
    } else {
      return res.status(500).json({ message: 'Failed to sync encounters' });
    }
  } catch (error) {
    console.error('Error syncing encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Add a route to sync all users' encounters
router.post('/sync-all', async (req, res) => {
  try {
    // Get all users
    const users = await User.find({});
    
    // Track results
    const results = [];
    
    // Sync encounters for each user
    for (const user of users) {
      const success = await syncUserEncounters(user.username);
      
      if (success) {
        // Get updated user
        const updatedUser = await User.findOne({ username: user.username });
        results.push({
          username: user.username,
          success: true,
          encounterCount: updatedUser.encounters.length
        });
      } else {
        results.push({
          username: user.username,
          success: false
        });
      }
    }
    
    return res.status(200).json({
      message: `Synced encounters for ${results.length} users`,
      results
    });
  } catch (error) {
    console.error('Error syncing all encounters:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get user encounters with other user details
router.get('/user-encounters/:username', async (req, res) => {
  try {
    const { username } = req.params;
    console.log(`Fetching encounters for user: ${username}`);
    
    // First, sync encounters to ensure they're up to date
    await syncUserEncounters(username);
    
    // Get the user with their encounters
    const user = await User.findOne({ username }).lean();
    
    if (!user) {
      return res.status(404).json({ 
        message: `User ${username} not found`, 
        success: false 
      });
    }
    
    // If no encounters, return empty array
    if (!user.encounters || user.encounters.length === 0) {
      return res.status(200).json({
        message: `No encounters found for user ${username}`,
        encounters: [],
        success: true
      });
    }
    
    // Get all unique usernames from encounters
    const otherUsernames = new Set();
    user.encounters.forEach(encounter => {
      if (encounter.user1 !== username) otherUsernames.add(encounter.user1);
      if (encounter.user2 !== username) otherUsernames.add(encounter.user2);
    });
    
    // Update emails for users if needed (don't await to avoid slowing down response)
    Array.from(otherUsernames).forEach(otherUsername => {
      updateUserEmailIfNeeded(otherUsername);
    });
    
    // Fetch details of all other users involved in encounters
    const otherUsers = await User.find({
      username: { $in: Array.from(otherUsernames) }
    }).select('username email').lean();
    
    // Create a map for quick lookup of other user details
    const userDetailsMap = {};
    otherUsers.forEach(otherUser => {
      userDetailsMap[otherUser.username] = {
        username: otherUser.username,
        email: otherUser.email || 'No email provided'
      };
    });
    
    // Enhance encounters and normalize so current user is always user1
    const enhancedEncounters = user.encounters.map(encounter => {
      let normalizedEncounter;
      let otherUsername;
      
      // If the current user is already user1, keep it that way
      if (encounter.user1 === username) {
        normalizedEncounter = { ...encounter };
        otherUsername = encounter.user2;
      } 
      // If the current user is user2, swap user1 and user2
      else {
        normalizedEncounter = {
          ...encounter,
          user1: encounter.user2,
          user2: encounter.user1
        };
        otherUsername = encounter.user1;
      }
      
      // Add other user details
      const otherUserDetails = userDetailsMap[otherUsername] || { 
        username: otherUsername, 
        email: 'Unknown' 
      };
      
      return {
        ...normalizedEncounter,
        otherUser: otherUserDetails
      };
    });
    
    return res.status(200).json({
      message: `Found ${enhancedEncounters.length} encounters for user ${username}`,
      encounters: enhancedEncounters,
      success: true
    });
  } catch (error) {
    console.error('Error fetching user encounters:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.message,
      success: false 
    });
  }
});

// Process all encounters for a specific user (comprehensive approach)
router.post('/process-encounters/:username', async (req, res) => {
  // ... existing implementation
});

// Add a helper function to ensure user email is updated if available in logs
async function updateUserEmailIfNeeded(username) {
  try {
    // Find the user
    const user = await User.findOne({ username });
    if (!user || user.email) return; // Already has email or doesn't exist
    
    // Check for email in logs
    const latestLog = await Logs.findOne({ username }).sort({ uploadDate: -1 });
    if (latestLog && latestLog.email) {
      user.email = latestLog.email;
      await user.save();
      console.log(`Updated email for user ${username} to ${latestLog.email}`);
    }
  } catch (error) {
    console.error(`Error updating email for ${username}:`, error);
  }
}

module.exports = router; 