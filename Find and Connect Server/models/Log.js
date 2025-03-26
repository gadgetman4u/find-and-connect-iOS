const mongoose = require('mongoose');

//Log file schema
const LogSchema = new mongoose.Schema({
  filename: {
    type: String,
    required: true
  },
  username: {
    type: String,
    required: true
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