const mongoose = require('mongoose');

const tellLogSchema = new mongoose.Schema({
  logId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Log',
    required: true
  }
  // Any tell-specific fields can be added here
});

module.exports = mongoose.model('TellLog', tellLogSchema); 