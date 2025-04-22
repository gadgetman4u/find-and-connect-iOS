const mongoose = require('mongoose');

// Base schema without indexes for embedding in User documents
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

// Create a schema for the standalone model that includes the unique index
const StandaloneEncounterSchema = new mongoose.Schema({
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

// Add the index to the standalone schema only
StandaloneEncounterSchema.index({ user1: 1, user2: 1, startTime: 1 }, { unique: true });

// Create the model using the schema with indexes
const EncounterModel = mongoose.model('Encounter', StandaloneEncounterSchema);

module.exports = {
  EncounterSchema, // Export the schema WITHOUT indexes for embedding in User documents
  Encounter: EncounterModel // Export the model WITH indexes for direct use
};
