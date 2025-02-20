# Find and Connect – iOS Version

## Introduction  
This research project aims to understand human behavior and mobility patterns during physical events.  
It explores why people add others to their social networks and how groups form during an event.  
The goal is to develop a **contact recommendation system** that seamlessly connects people from offline interactions to online networks.  

---

## Project Overview  

### 🔹 Current Focus  
- Implementing **Bluetooth-based** scanning and advertising for encounters  
- Improving **background functionality** for iOS Bluetooth operations  
- Enhancing the **encounter algorithm** for accurate contact recommendations  

### ✅ To-Do List  
- [x] Complete the algorithm for creating a service  
- [x] Advertise the server to be visible to other devices  
- [x] Test the application’s ability to detect services  
- [x] Implement a naming algorithm for service identification  
- [x] Continue testing log functionality  
- [x] Finalize the encounter detection algorithm  
- [x] Debug and test algorithm performance  
- [x] Optimize code for better readability  
- [x] Parameterize the algorithm for custom input values  
- [x] Create test cases for parameter optimization  
- [x] Design and implement a **security protocol**  
- [x] Revise app architecture to support security features  
- [x] Adjust scanning frequency to **every 30 seconds for 5 seconds**  
- [x] Set up a **local server** for testing  
- [x] Use **Bluetooth beacons** for location tracking, selecting the strongest RSSI  
- [x] Implement **randomized EID generation** for broadcasting  
- [x] Update **encounter algorithm** for improved accuracy  

---

## 📝 Update Log

### 📅 February 20, 2025  
- Added username to **heardSet**
- Changed RSSI value for more accurate encounter detection
- Integrating encounter script into Swift

### 📅 February 18, 2025  
- Completed **heardSet** functionality.  
- Encountered bugs where **heardSet** works on one phone but not another.  
- 🔜 **Next Steps:** Investigate and debug **encounter algorithm**.  

### 📅 February 11, 2025  
- Updated **UI** and got **TellSet** working.  
- Challenge: Understanding the communication protocol.  
- 🔜 **Next Steps:** Complete **heardSet** implementation.  

### 📅 February 4, 2025  
- Completed **UI and beacon scanning** for room-based connections.  
- 🛠️ Issue: Connections drop randomly.  
- 🔜 **Next Steps:** Finalize **tellSet and heardSet** logging functionality.  

### 📅 January 28, 2025  
- Began researching **iOS background scanning & advertising** limitations.  
- Studied **CoreBluetooth framework** for Swift.  

---

## 🛠️ Technology Stack  
- **Language:** Swift  
- **Framework:** CoreBluetooth  
- **Backend:** Local server for testing  
- **Tools:** Xcode, GitHub  

---

