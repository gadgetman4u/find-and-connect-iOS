import csv
import json
import sys
import argparse
from datetime import datetime

def parse_args():
    parser = argparse.ArgumentParser(description='Find encounters between users')
    parser.add_argument('--max-idle', type=int, default=3, help='Maximum idle time between logs')
    parser.add_argument('--min-duration', type=int, default=3, help='Minimum encounter duration')
    parser.add_argument('--heard-log', required=True, help='Path to heard log file')
    parser.add_argument('--tell-log', required=True, help='Path to tell log file')
    return parser.parse_args()

def convertStringToDateTime(timeString, formatString):
    """Convert timestamp string to datetime object."""
    try:
        # Try parsing with the given format
        return datetime.strptime(timeString, formatString)
    except ValueError:
        # Handle potential format issues
        if '.0' in timeString and formatString == '%Y-%m-%d %H:%M:%S':
            # Remove microseconds if they exist but aren't in the format string
            cleaned_string = timeString.split('.')[0]
            return datetime.strptime(cleaned_string, formatString)
        # Try alternate format without microseconds
        elif formatString == '%Y-%m-%d %H:%M:%S.%f' and '.' not in timeString:
            return datetime.strptime(timeString, '%Y-%m-%d %H:%M:%S')
        raise  # Re-raise the exception if we can't handle it

def removeDuplicates(nested_list):
    """Removes duplicate lists in a nested list and sorts by the first element."""
    unique = {tuple(my_list) for my_list in nested_list}
    result = [list(tup) for tup in unique]
    result.sort(key=lambda x: x[0])
    return result

def timeBetween(time1, time2):
    """Returns the time difference in minutes."""
    time_difference_seconds = (time2 - time1).total_seconds()
    return round(time_difference_seconds / 60)

def getEncounterLocation(encounterLogs):
    """Finds the most frequent encounter location from logs."""
    location_counts = {}
    for log in encounterLogs:
        location = log[2]
        location_counts[location] = location_counts.get(location, 0) + 1

    return max(location_counts, key=location_counts.get)

def same_date(dt1, dt2):
    """Check if two datetime objects are on the same date."""
    return dt1.date() == dt2.date()

def findEncounter(maxIdle, minDuration, heardSet, tellSet):
    """Processes tell and heard logs to identify encounters."""
    
    tellLog_file_path = tellSet
    heardLog_file_path = heardSet

    jsonfile = []

    # Mapping EIDs to user info: {EID: [username, location, start_time, end_time]}
    EidToUsername = {}
    
    try: 
        with open(tellLog_file_path, mode='r', newline="") as file:
            tellLog_reader = csv.reader(file)

            first_line = next(tellLog_reader, None)
            if not first_line:
                print(json.dumps([]))
                return []

            try:
                # First try to parse with the new format (no microseconds)
                previous = [first_line[2], first_line[3], convertStringToDateTime(first_line[0], '%Y-%m-%d %H:%M:%S')]
            except ValueError:
                # Fallback to the old format with microseconds
                previous = [first_line[2], first_line[3], convertStringToDateTime(first_line[0], '%Y-%m-%d %H:%M:%S.%f')]
                
            eid = first_line[1]

            for row in tellLog_reader:
                try:
                    # Try both formats for each row
                    try:
                        timestamp = convertStringToDateTime(row[0], '%Y-%m-%d %H:%M:%S')
                    except ValueError:
                        timestamp = convertStringToDateTime(row[0], '%Y-%m-%d %H:%M:%S.%f')
                    
                    previous.append(timestamp)
                    EidToUsername[eid] = previous

                    previous = [row[2], row[3], timestamp]
                    eid = row[1]
                except Exception as e:
                    print(f"Warning: Could not process tell log row: {row}. Error: {str(e)}")
                    continue

            # Using the same date as the last entry but with end of day time
            last_date = previous[2].strftime('%Y-%m-%d')
            previous.append(convertStringToDateTime(f'{last_date} 23:59:59', '%Y-%m-%d %H:%M:%S'))
            EidToUsername[eid] = previous
    except FileNotFoundError:
        print(json.dumps({"error": "Tell log file not found"}))
        return []
    except Exception as e:
        print(json.dumps({"error": f"Error processing tell log: {str(e)}"}))
        return []

    # Process heard logs and match EIDs to users
    processedHeardLog = []
    deviceUserName = ""

    try: 
        with open(heardLog_file_path, mode='r', newline="") as file:
            heardLog_reader = csv.reader(file)

            for row in heardLog_reader:
                try:
                    if len(row) < 5:
                        print(f"Warning: Skipping heard log row with insufficient data: {row}")
                        continue
                        
                    heardEid = row[1]
                    deviceUserName = row[4]

                    if heardEid not in EidToUsername:
                        continue  # Skip if the EID is not in tellLog

                    EidList = EidToUsername[heardEid]
                    start_time, end_time = EidList[2], EidList[3]
                    
                    try:
                        # Try both formats for each row
                        try:
                            check_time = convertStringToDateTime(row[0], '%Y-%m-%d %H:%M:%S')
                        except ValueError:
                            check_time = convertStringToDateTime(row[0], '%Y-%m-%d %H:%M:%S.%f')
                    except Exception as e:
                        print(f"Warning: Could not parse timestamp in heard log: {row[0]}. Error: {str(e)}")
                        continue

                    # Only process logs from the same date and matching location
                    if start_time <= check_time <= end_time and EidList[1] == row[2] and same_date(start_time, check_time):
                        processedHeardLog.append([check_time, EidList[0], row[2]])
                except Exception as e:
                    print(f"Warning: Could not process heard log row: {row}. Error: {str(e)}")
                    continue
    except FileNotFoundError:
        print(json.dumps({"error": "Heard log file not found"}))
        return []
    except Exception as e:
        print(json.dumps({"error": f"Error processing heard log: {str(e)}"}))
        return []
    
    # Group logs by username and date
    uniqueUserHeardMap = {}

    for row in processedHeardLog:
        userName = row[1]
        date_key = row[0].strftime('%Y-%m-%d')
        user_date_key = f"{userName}_{date_key}"
        uniqueUserHeardMap.setdefault(user_date_key, []).append(row)

    # Finding encounters using a sliding window approach
    for user_date_key, encounterLogWithUser in uniqueUserHeardMap.items():
        userName = user_date_key.split('_')[0]  # Extract username from the key
        encounterLogWithUser = removeDuplicates(encounterLogWithUser)
        size = len(encounterLogWithUser)

        if size > 1:
            encounterStart = 0
            current = 0
            encounterEnd = 1

            while encounterEnd < size:
                duration = timeBetween(encounterLogWithUser[current][0], encounterLogWithUser[encounterEnd][0])

                if duration <= maxIdle:
                    encounterEnd += 1
                    current += 1
                else:
                    encounterDuration = timeBetween(encounterLogWithUser[encounterStart][0], encounterLogWithUser[encounterEnd - 1][0])

                    if encounterDuration >= minDuration:
                        # Format datetime objects for output - use consistent format
                        startTime = encounterLogWithUser[encounterStart][0].strftime('%Y-%m-%d %H:%M:%S')
                        endTime = encounterLogWithUser[encounterEnd - 1][0].strftime('%Y-%m-%d %H:%M:%S')
                        encounterLocation = getEncounterLocation(encounterLogWithUser[encounterStart:encounterEnd])

                        jsonfile.append({
                            "userName": userName,
                            "startTime": startTime,
                            "endTime": endTime,
                            "encounterDuration": encounterDuration,
                            "encounterLocation": encounterLocation,
                            "deviceUserName": deviceUserName
                        })

                    encounterStart = encounterEnd
                    current = encounterStart
                    encounterEnd += 1

            # Final check for last batch
            encounterDuration = timeBetween(encounterLogWithUser[encounterStart][0], encounterLogWithUser[encounterEnd - 1][0])
            
            if (current > 0 and 
                timeBetween(encounterLogWithUser[current - 1][0], encounterLogWithUser[encounterEnd - 1][0]) <= maxIdle and 
                encounterDuration >= minDuration):
                
                startTime = encounterLogWithUser[encounterStart][0].strftime('%Y-%m-%d %H:%M:%S')
                endTime = encounterLogWithUser[encounterEnd - 1][0].strftime('%Y-%m-%d %H:%M:%S')
                encounterLocation = getEncounterLocation(encounterLogWithUser[encounterStart:encounterEnd])

                jsonfile.append({
                    "userName": userName,
                    "startTime": startTime,
                    "endTime": endTime,
                    "encounterDuration": encounterDuration,
                    "encounterLocation": encounterLocation,
                    "deviceUserName": deviceUserName
                })

    # Print the results directly to stdout as JSON
    print(json.dumps(jsonfile, indent=2))
    return jsonfile

if __name__ == "__main__":
    args = parse_args()
    findEncounter(
        args.max_idle,
        args.min_duration,
        args.heard_log,
        args.tell_log
    ) 