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
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

console.log(process.env.MONGO_URI);

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI);

mongoose.connection.once("open", () => {
    console.log("Connected to DB!")
}).on("error", (error) => {
    console.log("Failed to connect " + error)
})

// Routes
app.use('/api/logs', require('./routes/logRoutes'));
app.use('/api/encounters', require('./routes/encounterRoutes'));
app.use('/view', require('./views/index'));

// Root route
app.get('/', (req, res) => {
  res.status(200).send('OK');
});


// Start server
// http://10.194.213.230:8080/api/logs
var server = app.listen(8080, "0.0.0.0", () => {
    console.log("Server is running on port 8080 at localhost")
})
