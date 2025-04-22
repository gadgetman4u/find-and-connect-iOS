// Script to drop the problematic index
const mongoose = require('mongoose');
require('dotenv').config();

async function dropIndex() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');
    
    // Get a reference to the users collection
    const db = mongoose.connection.db;
    const usersCollection = db.collection('users');
    
    console.log('Dropping the problematic encounters index...');
    try {
      // Drop the problematic index
      await usersCollection.dropIndex('encounters.user1_1_encounters.user2_1_encounters.startTime_1');
      console.log('Successfully dropped the index!');
    } catch (err) {
      if (err.code === 27) {
        console.log('Index does not exist.');
      } else {
        throw err;
      }
    }
    
    // Show remaining indexes
    const indexes = await usersCollection.indexes();
    console.log('Remaining indexes:', JSON.stringify(indexes, null, 2));
    
    console.log('Disconnecting from MongoDB...');
    await mongoose.disconnect();
    console.log('Done!');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

dropIndex(); 