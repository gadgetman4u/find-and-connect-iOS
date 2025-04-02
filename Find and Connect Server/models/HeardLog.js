const mongoose = require('mongoose');

const heardLogSchema = new mongoose.Schema({
  logId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Log',
    required: true
  }
  // Any heard-specific fields can be added here
});

module.exports = mongoose.model('HeardLog', heardLogSchema); 