#!/usr/bin/env python3
import sys
import json
import os
from datetime import datetime

def parse_heard_log(file_path):
    """Parse a HeardLog file and extract relevant data."""
    entries = []
    try:
        with open(file_path, 'r') as file:
            for line in file:
                line = line.strip()
                if not line:
                    continue
                
                # Example format: "EID: abc123, Location: DPI_2038, RSSI: -75, Time: 2023-05-12-14:30:45, Username: John"
                if "EID:" in line and "Location:" in line and "Time:" in line:
                    parts = line.split(', ')
                    entry = {}
                    for part in parts:
                        key, value = part.split(': ', 1)
                        entry[key] = value
                    
                    # Convert timestamp to datetime object for easier comparison
                    if 'Time' in entry:
                        try:
                            entry['Timestamp'] = datetime.strptime(entry['Time'], '%Y-%m-%d-%H:%M:%S')
                        except ValueError:
                            # Handle malformed timestamps
                            continue
                    
                    entries.append(entry)
        
        return entries
    except Exception as e:
        print(f"Error parsing HeardLog: {str(e)}", file=sys.stderr)
        return []

def parse_tell_log(file_path):
    """Parse a TellLog file and extract relevant data."""
    entries = []
    try:
        with open(file_path, 'r') as file:
            for line in file:
                line = line.strip()
                if not line:
                    continue
                
                # Example format: "EID: abc123, Location: DPI_2038, Time: 2023-05-12-14:30:45, Username: John"
                if "EID:" in line and "Location:" in line and "Time:" in line:
                    parts = line.split(', ')
                    entry = {}
                    for part in parts:
                        key, value = part.split(': ', 1)
                        entry[key] = value
                    
                    # Convert timestamp to datetime object for easier comparison
                    if 'Time' in entry:
                        try:
                            entry['Timestamp'] = datetime.strptime(entry['Time'], '%Y-%m-%d-%H:%M:%S')
                        except ValueError:
                            # Handle malformed timestamps
                            continue
                    
                    entries.append(entry)
        
        return entries
    except Exception as e:
        print(f"Error parsing TellLog: {str(e)}", file=sys.stderr)
        return []

def detect_encounters(heard_entries, tell_entries, time_threshold_seconds=300):
    """
    Detect encounters by matching EIDs and timestamps.
    Returns a list of encounters.
    """
    encounters = []
    
    for heard in heard_entries:
        for tell in tell_entries:
            # Match EIDs
            if heard.get('EID') == tell.get('EID'):
                # Check if timestamps are close enough
                if 'Timestamp' in heard and 'Timestamp' in tell:
                    time_diff = abs((heard['Timestamp'] - tell['Timestamp']).total_seconds())
                    
                    if time_diff <= time_threshold_seconds:
                        # Calculate confidence (higher for closer timestamps)
                        confidence = 1.0 - (time_diff / time_threshold_seconds)
                        
                        encounters.append({
                            'eid': heard.get('EID'),
                            'location': heard.get('Location'),
                            'timestamp': heard['Timestamp'].strftime('%Y-%m-%d-%H:%M:%S'),
                            'heard_username': heard.get('Username'),
                            'tell_username': tell.get('Username'),
                            'confidence': confidence,
                            'time_difference_seconds': time_diff
                        })
    
    return encounters

def main():
    """Main entry point for the encounter detection algorithm."""
    # Check if we have the correct number of arguments
    if len(sys.argv) < 3:
        print("Usage: python EncounterAlgorithm.py <heard_log_path> <tell_log_path>", file=sys.stderr)
        sys.exit(1)
    
    heard_log_path = sys.argv[1]
    tell_log_path = sys.argv[2]
    
    # Validate file paths
    if not os.path.exists(heard_log_path):
        print(f"Error: HeardLog file not found: {heard_log_path}", file=sys.stderr)
        sys.exit(1)
    
    if not os.path.exists(tell_log_path):
        print(f"Error: TellLog file not found: {tell_log_path}", file=sys.stderr)
        sys.exit(1)
    
    # Parse log files
    heard_entries = parse_heard_log(heard_log_path)
    tell_entries = parse_tell_log(tell_log_path)
    
    # Detect encounters
    encounters = detect_encounters(heard_entries, tell_entries)
    
    # Output the results as JSON
    print(json.dumps(encounters))

if __name__ == "__main__":
    main()
