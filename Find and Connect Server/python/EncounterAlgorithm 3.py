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

def convertStringtoTimeObj(timeString, formatString):
    return datetime.strptime(timeString, formatString).time()

def removeDuplicates(nested_list):
    """Removes duplicate lists in a nested list and sorts by the first element."""
    unique = {tuple(my_list) for my_list in nested_list}
    result = [list(tup) for tup in unique]
    result.sort(key=lambda x: x[0])
    return result

def timeBetween(time1, time2):
    """Returns the time difference in minutes, correctly rounded."""
    seconds1 = time1.hour * 3600 + time1.minute * 60 + time1.second
    seconds2 = time2.hour * 3600 + time2.minute * 60 + time2.second

    time_difference_seconds = seconds2 - seconds1
    return round(time_difference_seconds / 60)  # Correct rounding issue

def getEncounterLocation(encounterLogs):
    """Finds the most frequent encounter location from logs."""
    location_counts = {}
    for log in encounterLogs:
        location = log[2]
        location_counts[location] = location_counts.get(location, 0) + 1

    return max(location_counts, key=location_counts.get)

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

            previous = [first_line[2], first_line[3], convertStringtoTimeObj(first_line[0], '%H:%M:%S.%f')]
            eid = first_line[1]

            for row in tellLog_reader:
                previous.append(convertStringtoTimeObj(row[0], '%H:%M:%S.%f'))
                EidToUsername[eid] = previous

                previous = [row[2], row[3], convertStringtoTimeObj(row[0], '%H:%M:%S.%f')]
                eid = row[1]

            previous.append(convertStringtoTimeObj('23:59:59.0', '%H:%M:%S.%f'))
            EidToUsername[eid] = previous
    except FileNotFoundError:
        print(json.dumps({"error": "Tell log file not found"}))
        return []

    # Process heard logs and match EIDs to users
    processedHeardLog = []
    deviceUserName = ""

    try: 
        with open(heardLog_file_path, mode='r', newline="") as file:
            heardLog_reader = csv.reader(file)

            for row in heardLog_reader:
                heardEid = row[1]
                deviceUserName = row[4]

                if heardEid not in EidToUsername:
                    continue  # Skip if the EID is not in tellLog

                EidList = EidToUsername[heardEid]
                start_time, end_time = EidList[2], EidList[3]
                check_time = convertStringtoTimeObj(row[0], '%H:%M:%S.%f')

                if start_time <= check_time <= end_time and EidList[1] == row[2]:
                    processedHeardLog.append([check_time, EidList[0], row[2]])
    except FileNotFoundError:
        print(json.dumps({"error": "Heard log file not found"}))
        return []
    
    # Sorting logs into users
    uniqueUserHeardMap = {}

    for row in processedHeardLog:
        userName = row[1]
        uniqueUserHeardMap.setdefault(userName, []).append(row)

    # Finding encounters using a sliding window approach
    for user, encounterLogWithUser in uniqueUserHeardMap.items():
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
                        startTime = encounterLogWithUser[encounterStart][0].strftime('%H:%M:%S.%f')
                        endTime = encounterLogWithUser[encounterEnd - 1][0].strftime('%H:%M:%S.%f')
                        encounterLocation = getEncounterLocation(encounterLogWithUser[encounterStart:encounterEnd])

                        jsonfile.append({
                            "startTime": startTime,
                            "endTime": endTime,
                            "encounterDuration": encounterDuration,
                            "encounterLocation": encounterLocation
                        })

                    encounterStart = encounterEnd
                    current = encounterStart
                    encounterEnd += 1

            # Final check for last batch
            encounterDuration = timeBetween(encounterLogWithUser[encounterStart][0], encounterLogWithUser[encounterEnd - 1][0])
            
            if timeBetween(encounterLogWithUser[current - 1][0], encounterLogWithUser[encounterEnd - 1][0]) <= maxIdle and encounterDuration >= minDuration:
                startTime = encounterLogWithUser[encounterStart][0].strftime('%H:%M:%S.%f')
                endTime = encounterLogWithUser[encounterEnd - 1][0].strftime('%H:%M:%S.%f')
                encounterLocation = getEncounterLocation(encounterLogWithUser)

                jsonfile.append({
                    "startTime": startTime,
                    "endTime": endTime,
                    "encounterDuration": encounterDuration,
                    "encounterLocation": encounterLocation
                })

    # Print the results directly to stdout as JSON (instead of writing to file)
    print(json.dumps(jsonfile))
    return jsonfile

if __name__ == "__main__":
    args = parse_args()
    findEncounter(
        args.max_idle,
        args.min_duration,
        args.heard_log,
        args.tell_log
    )