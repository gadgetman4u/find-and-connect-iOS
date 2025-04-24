const mongoose = require('mongoose');
const { LogSchema } = require('./Log.js');
const { EncounterSchema } = require('./Encounter.js')

// Create a version of EncounterSchema for embedding that excludes indexes
const EmbeddedEncounterSchema = new mongoose.Schema(
  EncounterSchema.obj, 
  { 
    _id: true, 
    id: false,
    _indexes: [] // Clear any indexes from the embedded schema
  }
);

const UserSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true
  },
  email: {
    type: String,
    sparse: true, // Allow null/undefined but enforce uniqueness if provided
    trim: true
  },
  heardLog: {
    type: LogSchema,
    required: false
  },
  tellLog: {
    type: LogSchema,
    required: false
  },
  encounters: {
    type: [EmbeddedEncounterSchema], // Use the embedded version without indexes
    required: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', UserSchema); 