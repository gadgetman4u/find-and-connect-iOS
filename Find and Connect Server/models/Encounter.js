const mongoose = require('mongoose');

const EncounterSchema = new mongoose.Schema({
  user1: {
    type: String,
    required: true
  },
  user2: {
    type: String,
    required: true
  },
  heardLogId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Log'
  },
  tellLogId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Log'
  },
  location: {
    type: String,
    required: true
  },
  startTime: {
    type: Date,
    required: true
  },
  endTime: {
    type: Date,
    required: true
  },
  duration: {
    type: Number,
    required: true
  },
  detectionDate: {
    type: Date,
    default: Date.now
  }
});

// Ensure we don't create duplicate encounters
EncounterSchema.index({ user1: 1, user2: 1, timestamp: 1 }, { unique: true });

module.exports = mongoose.model('Encounter', EncounterSchema); 