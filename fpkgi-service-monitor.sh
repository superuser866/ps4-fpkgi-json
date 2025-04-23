#!/bin/bash

# Directory to monitor
MONITOR_DIR="/nfs/PS4/Games"
# Check file to verify successful mount
CHECK_FILE="$MONITOR_DIR/mount.chk"  

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
	    mount $MONITOR_DIR
	fi
}

######## START ########

check_mount

# Use inotifywait to recursively monitor directory 
inotifywait -m -r -e create --format "%w%f" "$MONITOR_DIR" | while read FILE
do
    # Verify file extension
    FILE_LOWER=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$FILE_LOWER" =~ \.(pkg)$ ]]; then
        # Create or update request file with timestamp
        echo_ts "Setting update request for: $FILE"
        echo "$(date +%s)" > "$UPDATE_REQUEST_FILE"
    fi
done

