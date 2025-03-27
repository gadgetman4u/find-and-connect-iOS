const mongoose = require('mongoose');

const TellLogSchema = new mongoose.Schema({
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
  uploadDate: {
    type: Date,
    default: Date.now
  },
  processed: {
    type: Boolean,
    default: false
  }
});

module.exports = mongoose.model('TellLog', TellLogSchema); 