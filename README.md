# Find and Connect iOS

## Introduction
This research project aims to understand human behavior and mobility patterns during physical events. It explores why people add others to their social networks and how groups form during an event. The goal is to develop a **contact recommendation system** that seamlessly connects people from offline interactions to online networks.

## Installation

### Download
1. Go to the [Github](https://github.com/illinoisdpi/msn-encounters-ios) page and ensure you're on the main branch
2. Press the green "〈〉 Code" drop down, and press open with XCode
3. Clone the project in to a folder of your choice.
4. Connect your device to your laptop and select it to run in XCode
5. Press Run and Install!

### Run the Application
1. Enable developer mode on your iPhone
2. Connect your iPhone (iOS15+) to your Mac, XCode will automatically detect your iPhone
3. Click the triangular "Run" button on the top of XCode - Find and Connect will be installed and running on your iPhone

## User Guide

### How to access the heardLog and tellLog?
1. The heardLog and tellLog are available for display in the app by simply tapping on their buttons
2. There is a drop down menu beside each log that allows **two additional functionalities**
   - Share: This button allows users to share their logs through Airdrop, Messages, Outlook, etc.
   - Upload: This button uploads the log to the backend server, once both the tellLog and heardLog are uploaded to the server, the user can "Process Encounters"

### How to find Encounters?
1. Once both logs are uploaded to the server, the "Process Encounters" button lights up and becomes available
2. Users can press on "Process Encounters", which runs the python script *EncounterAlgorithm.py* on the backend server
3. Using the most recently uploaded heardLog and tellLog, the algorithm detects and saves Encounters to the database
4. After processing, users can press "View my Encounters" to fetch Encounters from the database. The fetched encounters show other users you have encountered

## Code Documentation

### iOS Overview
The "Find and Connect" iOS application is designed to facilitate proximity-based encounter tracking through Bluetooth Low Energy technology. The app operates in a dual mode system where it simultaneously broadcasts its presence (as a peripheral) and scans for other devices (as a central). Built with Swift and utilizing Apple's CoreBluetooth framework, the application leverages ephemeral identifiers (EIDs) that rotate periodically to maintain user privacy while still enabling encounter detection.

### Core Components

1. **API Manager (APIManager.swift)**
   - Manages all network communication with the backend server
   - Implements singleton pattern for app-wide access
   - Key methods include uploadLog, processEncounters, and getEncounters

2. **Encounter Model (Encounter.swift)**
   - Core data structures for encounter information
   - Handles API responses and data modeling
   - Includes structures for UploadResponse, ProcessResponse, and UserEncountersResponse

3. **Bluetooth Scanning (DeviceScanManager.swift)**
   - Implements CBCentralManagerDelegate for device discovery
   - Handles location awareness and logging system
   - Maintains discovered device records

4. **Bluetooth Advertising (BluetoothPeripheralManager.swift)**
   - Manages device advertising through CBPeripheralManagerDelegate
   - Implements periodic ID rotation for privacy
   - Handles tell log management

5. **Beacon Detection (BeaconScanManager.swift)**
   - Manages fixed location beacon detection
   - Determines nearest beacon for location tracking
   - Handles beacon timeout management

## Backend Documentation

### Overview
The backend server provides APIs for managing and processing device logs to detect encounters between users. It includes functionality for uploading logs, processing encounters, and retrieving encounter data.

### API Endpoints

#### Log Management
```javascript
POST /api/logs/upload
DELETE /api/logs/delete/user/:username/:logType
```

#### Encounter Management
```javascript
GET /api/encounters/
GET /api/encounters/user/:userId
POST /api/encounters/sync/:username
GET /api/encounters/user-encounters/:username
```

### Encounter Detection Process
1. Users upload heard logs and tell logs through API
2. System compares heard logs against tell logs from other users
3. Encounters detected using Python algorithm
4. Detected encounters stored in database
5. User documents updated with encounters

## Technologies

### Mobile
- Languages: Swift
- Frameworks: SwiftUI, CoreBluetooth, Foundation
- Tools: XCode, Git

### Backend (Deployed on Azure)
- Languages: Javascript, Python
- Framework: Express
- Tools: MongoDB, Git
