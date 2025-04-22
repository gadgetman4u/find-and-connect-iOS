const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./models/User');

async function debugUser() {
  try {
    // Connect to the database
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB successfully');

    // Try to create a new user
    console.log('Attempting to create a new user for Jeremy...');
    const newUser = new User({
      username: 'Jeremy',
      encounters: []
    });

    // Save the user and log any errors in detail
    await newUser.save();
    console.log('User created successfully!');
    
    // Disconnect
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  } catch (error) {
    console.error('Error creating user:');
    console.error(JSON.stringify(error, null, 2));
    if (error.code === 11000) {
      console.error('Duplicate key error details:');
      console.error(JSON.stringify(error.keyPattern, null, 2));
      console.error(JSON.stringify(error.keyValue, null, 2));
    }
    process.exit(1);
  }
}

debugUser(); 