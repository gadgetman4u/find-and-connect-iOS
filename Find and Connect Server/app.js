const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const bodyParser = require('body-parser');
const path = require('path');

// Load environment variables
dotenv.config();

// Initialize express
const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Connect to MongoDB
mongoose.connect('mongodb://localhost:27017/newDB')

mongoose.connection.once("open", () => {
    console.log("Connected to DB!")
}).on("error", (error) => {
    console.log("Failed to connect " + error)
})

// Routes
app.use('/api/logs', require('./routes/logRoutes'));
app.use('/api/encounters', require('./routes/encounterRoutes'));
app.use('/view', require('./routes/viewRoutes'));

// Root route
app.get('/', (req, res) => {
  res.send('Find and Connect Server is running');
});

// Start server
// http://10.194.213.230:8081/api/logs
var server = app.listen(8081, "localhost", () => {
    console.log("Server is running on port 8081 at localhost")
})