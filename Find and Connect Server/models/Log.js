const mongoose = require('mongoose');

//Log file schema
const LogSchema = new mongoose.Schema({
  filename: {
    type: String,
    required: true
  },
  originalName: {
    type: String
  },
  path: {
    type: String,
    required: true
  },
  size: {
    type: Number
  },
  username: {
    type: String,
    required: true,
    index: true
  },
  email: {
    type: String,
    index: true
  },
  logType: {
    type: String,
    enum: ['heardLog', 'tellLog'],
    required: true
  },
  uploadDate: {
    type: Date,
    default: Date.now
  },
  processed: {
    type: Boolean,
    default: false
  }
});

module.exports = mongoose.model('Log', LogSchema); 