#!/bin/bash

UPDATE_URL="http://odin.lan/PS4/"
MONITOR_DIR="/nfs/PS4/Games"
#How many seconds to wait (in order to allow pkg transfer to complete) 
GRACE_PERIOD=0

# File update request
UPDATE_REQUEST_FILE="/tmp/fpkgi_update_request"
LOCK_FILE="/tmp/fpkgi-update-json.lock"

# Print with timestamp
echo_ts() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# If script is still running, exit
if [ -f "$LOCK_FILE" ]; then
    echo_ts "Script is already running. Exiting."
    exit 1
fi

# Crea il file di lock
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT


# Check the request file
if [ -f "$UPDATE_REQUEST_FILE" ]; then
    # Print timestamp from file
    LAST_UPDATE_TIMESTAMP=$(cat "$UPDATE_REQUEST_FILE")
    echo_ts "Request file found. Timestamp: $LAST_UPDATE_TIMESTAMP"

    # Delete request file
    rm -f "$UPDATE_REQUEST_FILE"
    echo_ts "Request file deleted."

    echo_ts "Waiting the grace period of $GRACE_PERIOD seconds..."
    sleep $GRACE_PERIOD
    
    # Update json
    echo_ts "Updating json..."
    cd $MONITOR_DIR
    ./ps4-fpkgi-json.sh $UPDATE_URL
#else
#    echo_ts "Request file not found."
fi

