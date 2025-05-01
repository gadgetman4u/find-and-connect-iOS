const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { Logs } = require('../models/Log');
const mongoose = require('mongoose');

// MongoDB diagnostics endpoint
router.get('/diagnostics', async (req, res) => {
  try {
    // Test connection status
    const connectionState = mongoose.connection.readyState;
    const connectionStates = ['disconnected', 'connected', 'connecting', 'disconnecting'];
    
    // Try a basic operation
    let operationSuccess = false;
    let operationError = null;
    let userCount = 0;
    let logCount = 0;
    
    try {
      userCount = await User.countDocuments();
      logCount = await Logs.countDocuments();
      operationSuccess = true;
    } catch (err) {
      operationError = err.toString();
    }
    
    // Get connection details
    const connDetails = {
      host: mongoose.connection.host,
      port: mongoose.connection.port,
      name: mongoose.connection.name,
      user: mongoose.connection.user ? "Set" : "Not set",
      ssl: mongoose.connection.client ? mongoose.connection.client.options.ssl : "Unknown",
      protocol: mongoose.connection.client ? mongoose.connection.client.options.useUnifiedTopology : "Unknown"
    };
    
    // Check environment variables
    const envVars = {
      NODE_ENV: process.env.NODE_ENV || "Not set",
      MONGO_URI_SET: process.env.MONGO_URI ? "Yes" : "No",
      SERVER_TYPE: process.env.SERVER_TYPE || "Not set" // Add any other relevant env vars
    };
    
    res.status(200).json({
      success: true,
      connection: {
        state: connectionStates[connectionState] || "unknown",
        stateCode: connectionState,
        details: connDetails
      },
      database: {
        operationSuccess,
        operationError,
        userCount,
        logCount
      },
      environment: envVars,
      serverTime: new Date().toISOString()
    });
  } catch (error) {
    console.error('MongoDB diagnostic error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Diagnostic error', 
      error: error.toString(),
      stack: error.stack
    });
  }
});

// Get all users
router.get('/', async (req, res) => {
  try {
    const users = await User.find().select('username email encounters').lean();
    res.status(200).json({ 
      message: `Found ${users.length} users`,
      users,
      success: true
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.message,
      success: false 
    });
  }
});

// Get a specific user
router.get('/:username', async (req, res) => {
  try {
    const { username } = req.params;
    const user = await User.findOne({ username }).lean();
    
    if (!user) {
      return res.status(404).json({ 
        message: `User ${username} not found`, 
        success: false 
      });
    }
    
    res.status(200).json({ 
      message: `Found user ${username}`,
      user,
      success: true
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.message,
      success: false 
    });
  }
});

// Create a user
router.post('/', async (req, res) => {
  try {
    const { username, email } = req.body;
    
    if (!username) {
      return res.status(400).json({ 
        message: 'Username is required', 
        success: false 
      });
    }
    
    // Check if user already exists
    let user = await User.findOne({ username });
    
    if (user) {
      return res.status(400).json({ 
        message: `User ${username} already exists`, 
        user,
        success: false 
      });
    }
    
    // Create new user
    user = new User({
      username,
      email: email || '',
      encounters: []
    });
    
    const savedUser = await user.save();
    
    res.status(201).json({ 
      message: `User ${username} created successfully`,
      user: savedUser,
      success: true
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.toString(),
      stack: error.stack,
      success: false 
    });
  }
});

// Fix user from logs
router.post('/fix/:username', async (req, res) => {
  try {
    const { username } = req.params;
    
    // Check if user exists
    let user = await User.findOne({ username });
    
    // Find logs for this user
    const logs = await Logs.find({ username });
    
    if (logs.length === 0) {
      return res.status(404).json({ 
        message: `No logs found for user ${username}`, 
        success: false 
      });
    }
    
    // Get email from most recent log if available
    const latestLog = logs.sort((a, b) => 
      new Date(b.uploadDate) - new Date(a.uploadDate)
    )[0];
    
    const email = latestLog.email || '';
    
    if (!user) {
      // Create new user
      user = new User({
        username,
        email,
        encounters: []
      });
      
      // Add logs to user
      const heardLog = logs.find(log => log.logType === 'heardLog');
      const tellLog = logs.find(log => log.logType === 'tellLog');
      
      if (heardLog) user.heardLog = heardLog;
      if (tellLog) user.tellLog = tellLog;
      
      const savedUser = await user.save();
      
      return res.status(201).json({ 
        message: `User ${username} created successfully from logs`,
        user: savedUser,
        success: true
      });
    } else {
      // Update user with logs
      const heardLog = logs.find(log => log.logType === 'heardLog');
      const tellLog = logs.find(log => log.logType === 'tellLog');
      
      if (heardLog) user.heardLog = heardLog;
      if (tellLog) user.tellLog = tellLog;
      
      if (email && (!user.email || user.email !== email)) {
        user.email = email;
      }
      
      const savedUser = await user.save();
      
      return res.status(200).json({ 
        message: `User ${username} updated from logs`,
        user: savedUser,
        success: true
      });
    }
  } catch (error) {
    console.error('Error fixing user:', error);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.toString(),
      stack: error.stack,
      success: false 
    });
  }
});

module.exports = router; 