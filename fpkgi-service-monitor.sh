#!/bin/bash

# Cartella da monitorare
MONITOR_DIR="/nfs/PS4/Games"

CHECK_FILE="$MONITOR_DIR/mount.chk"  # File di controllo per verificare il mount

# File di richiesta per aggiornamento
UPDATE_REQUEST_FILE="/tmp/fpkgi_update_request"

# Funzione per stampare messaggi con timestamp
echo_ts() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Funzione per verificare il montaggio
check_mount() {
	# Verifica se il file di controllo esiste
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

# Usa inotifywait per monitorare la cartella ricorsivamente
inotifywait -m -r -e create --format "%w%f" "$MONITOR_DIR" | while read FILE
do
    # Verifica estensione del file
    FILE_LOWER=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$FILE_LOWER" =~ \.(pkg)$ ]]; then
        # Crea o aggiorna il file di richiesta con il timestamp corrente
        echo_ts "Setting XML update request for: $FILE"
        echo "$(date +%s)" > "$UPDATE_REQUEST_FILE"
    fi
done
