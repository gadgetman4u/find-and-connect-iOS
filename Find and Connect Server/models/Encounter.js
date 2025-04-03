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
  startTime: {
    type: String,
    required: true
  },
  endTime: {
    type: String,
    required: true
  },
  encounterLocation: {
    type: String,
    required: true
  },
  encounterDuration: {
    type: Number,
    required: true
  }
});

// Ensure we don't create duplicate encounters
EncounterSchema.index({ user1: 1, user2: 1, startTime: 1 }, { unique: true });

module.exports = mongoose.model('Encounter', EncounterSchema); 