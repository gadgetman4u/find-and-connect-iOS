/**
 * Home routes
 */

const express = require('express');
const router = express.Router();

// Root route - redirect to logs
router.get('/', (req, res) => {
  res.redirect('/view/logs');
});

module.exports = router; 