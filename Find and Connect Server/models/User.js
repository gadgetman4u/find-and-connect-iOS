const mongoose = require('mongoose');
const { LogSchema } = require('./Log.js');
const { EncounterSchema } = require('./Encounter.js')

const UserSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true
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
    type: [EncounterSchema],
    required: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', UserSchema); 