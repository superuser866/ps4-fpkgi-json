#!/bin/bash

# Directory to monitor
MONITOR_DIR="/nfs/PS4/Games" 
# Check file to verify successful mount
CHECK_FILE="$MONITOR_DIR/mount.chk"  
# Check interval in seconds
INTERVAL=60
EXT=".pkg"
# Request file
UPDATE_REQUEST_FILE="/tmp/fpkgi_update_request"

# Print message with timestamp
echo_ts() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to verify mount
check_mount() {
	if [ -f "$CHECK_FILE" ]; then
	    echo_ts "Mount check file found."
	else
	    echo_ts "Mount check file not found. Wating 60 seconds..."
	    sleep 60
	    echo_ts "Mounting $MONITOR_DIR ..."
	    #mount $MONITOR_DIR
	    mount /nfs/PS4
	fi
}

######## START ########

check_mount

# Array of current pkg files
declare -A SEEN_FILES

echo_ts "Monitoring $MONITOR_DIR for new *$EXT files (interval: ${INTERVAL}s)..."

# First pass to load the current list
while IFS= read -r -d '' file; do
    if [[ -z "${SEEN_FILES["$file"]}" ]]; then
        SEEN_FILES["$file"]=1
    fi
done < <(find "$MONITOR_DIR" -type f -name "*$EXT" -print0)

echo_ts "Current list loaded. Starting monitoring..."

while true; do
    # find .pkg, save in temp array
    while IFS= read -r -d '' file; do
        if [[ -z "${SEEN_FILES["$file"]}" ]]; then
            echo_ts "New file: $file"
            SEEN_FILES["$file"]=1
            echo_ts "Setting update request for: $file"
            echo "$(date +%s)" > "$UPDATE_REQUEST_FILE"

	fi
    done < <(find "$MONITOR_DIR" -type f -name "*$EXT" -print0)
    sleep "$INTERVAL"
done
