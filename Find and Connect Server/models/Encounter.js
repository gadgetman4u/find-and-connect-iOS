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
  location: String,
  timestamp: Date,
  confidence: Number,
  detectionDate: {
    type: Date,
    default: Date.now
  }
});

// Ensure we don't create duplicate encounters
EncounterSchema.index({ user1: 1, user2: 1, timestamp: 1 }, { unique: true });

module.exports = mongoose.model('Encounter', EncounterSchema); 