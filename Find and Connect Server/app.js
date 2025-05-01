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

// Detailed MongoDB connection logging
console.log("MongoDB URI available:", process.env.MONGO_URI ? "Yes" : "No");
if (process.env.MONGO_URI) {
  // Mask the actual URI but show format for debugging
  const maskedUri = process.env.MONGO_URI.replace(/:\/\/(.*):(.*)@/, '://*****:*****@');
  console.log("Connecting to MongoDB with URI format:", maskedUri);
} else {
  console.error("MONGO_URI environment variable is not set!");
}

// Connect to MongoDB with better error handling
try {
  mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    serverSelectionTimeoutMS: 10000, // Timeout after 10s instead of default 30s
  });
  
  mongoose.connection.once("open", () => {
    console.log("Connected to MongoDB successfully!");
    
    // Display connection info
    const { host, port, name } = mongoose.connection;
    console.log(`MongoDB connection details - Host: ${host}, Port: ${port}, DB: ${name}`);
  }).on("error", (error) => {
    console.error("MongoDB connection error:", error);
  });
} catch (error) {
  console.error("Failed to connect to MongoDB:", error);
}

// Routes
app.use('/api/logs', require('./routes/logRoutes'));
app.use('/api/encounters', require('./routes/encounterRoutes'));
app.use('/api/users', require('./routes/userRoutes'));
app.use('/view', require('./views/index'));

// Root route with diagnostics
app.get('/', (req, res) => {
  const diagnostics = {
    serverTime: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    mongoConnected: mongoose.connection.readyState === 1,
    mongoDbConnectionStatus: getMongoStatus(),
    routes: [
      '/api/logs',
      '/api/encounters',
      '/api/users',
      '/view'
    ]
  };
  
  res.status(200).json({
    status: 'OK',
    message: 'Server is running',
    diagnostics
  });
});

function getMongoStatus() {
  const states = ['disconnected', 'connected', 'connecting', 'disconnecting'];
  return states[mongoose.connection.readyState] || 'unknown';
}

// Start server
// http://10.194.213.230:8080/api/logs
var server = app.listen(8080, "0.0.0.0", () => {
    console.log("Server is running on port 8080 at localhost")
})
