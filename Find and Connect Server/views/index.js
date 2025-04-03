/**
 * Main file that combines all view routes
 */

const express = require('express');
const router = express.Router();

// Import all route modules
const homeRoutes = require('./routes/homeRoutes');
const logListRoutes = require('./routes/logListRoutes');
const logViewRoutes = require('./routes/logViewRoutes');
const algorithmRoutes = require('./routes/algorithmRoutes');

// Use all route modules
router.use('/', homeRoutes);
router.use('/', logListRoutes);
router.use('/', logViewRoutes);
router.use('/', algorithmRoutes);

module.exports = router; 