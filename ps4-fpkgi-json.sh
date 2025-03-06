#!/bin/bash

###
# ./ps4-fpkgi-json.sh http://server.lan/PS4/

# Parameters check
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <serverURL>"
    echo "This sh must reside in the same directory with JSONs and PKGs" 
    exit 1
fi

INPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR+="/"
SERVER_URL="$1"
CONTAINER_NAME="openorbis"
JSON_GAMES="GAMES.json"
JSON_UPDATES="UPDATES.json"
JSON_DLC="DLC.json"
cGames=0
cDlc=0
cUpd=0

# Function to update JSON
update_json() {
    local json_file="$1"
    local key="$2"
    local value="$3"
    
    # Create a new file if it doesn't exist
    if [ ! -f "$json_file" ]; then
        echo '{"DATA": {}}' > "$json_file"
    fi
    
    # Update the JSON file by adding the new value to the "DATA" block
    jq --arg k "$key" --argjson v "$value" '.DATA += {($k): $v}' "$json_file" > tmp.json && mv tmp.json "$json_file"
}

# Function to check if a PKG is already listed in a JSON
pkg_exists_in_json() {
    local pkg_name="$1"
    local json_file="$2"
    
    result=$(grep -Fo "$pkg_name" "$json_file" | wc -l)
    
    # If found, return true (0) else false (1)
    if [ "$result" -gt 0 ]; then
        return 0
    else
        return 1 
    fi
}

cleanup_json() {
    local json_file="$1"

    # Se il file JSON non esiste o è vuoto, esci
    if [ ! -f "$json_file" ] || [ ! -s "$json_file" ]; then
        echo "JSON file $json_file not found or empty. Skipping cleanup."
        return
    fi

    # Read keys (PKG names) from JSON
    original_keys=$(jq -r '.DATA | keys[]' "$json_file")

    kept_keys=""
    deleted_keys=""

    # For every key (PKG name) in the JSON, checks if file exists
    while IFS= read -r key; do
        full_path=${key#$SERVER_URL}  # Rimuove la parte dell'URL per ottenere il percorso del file

        if [ -f "$full_path" ]; then
            kept_keys+="$key"$'\n'
        else
            echo "Record deleted (not found) in $json_file: $full_path"
            deleted_keys+="$key"$'\n'
        fi
    done <<< "$(echo "$original_keys")"

    # Removes invalid records from JSON
    jq --argjson kept_keys "$(echo "$kept_keys" | jq -R -s -c 'split("\n") | map(select(length > 0))')" '
        {DATA: ( .DATA | to_entries | map(select(.key as $key | $kept_keys | index($key))) | from_entries )}' \
        "$json_file" > tmp.json && mv tmp.json "$json_file"

    echo "Cleanup completed for $json_file"
}

# Create json files if they dont exist
if [ ! -f "$JSON_GAMES" ]; then
    echo '{"DATA": {}}' > "$JSON_GAMES"
fi
if [ ! -f "$JSON_UPDATES" ]; then
    echo '{"DATA": {}}' > "$JSON_UPDATES"
fi
if [ ! -f "$JSON_DLC" ]; then
    echo '{"DATA": {}}' > "$JSON_DLC"
fi

echo "Starting OpenOrbis Docker container..."
container_id=$(docker run --rm -dit --name "$CONTAINER_NAME" -w /workspace -u $(id -u):$(id -g) -v "$(realpath "$INPUT_DIR")":/workspace openorbisofficial/toolchain)

echo "Container started: $container_id"
#find "$INPUT_DIR" -type f -name "*.pkg" | while read -r pkg; do
while read -r pkg; do
    pkg_name=$(basename "$pkg")
    pkg_dir=$(dirname "$pkg")
    
    # Check if pkg is already in jsons
    if pkg_exists_in_json "$pkg_name" "$JSON_GAMES" || pkg_exists_in_json "$pkg_name" "$JSON_UPDATES" || pkg_exists_in_json "$pkg_name" "$JSON_DLC"; then
        echo "Skip: $pkg_name already listed in JSONs."
        continue
    fi
	
    # Check if pkg_dir is subdir of path
    if [[ "$pkg_dir" == "$INPUT_DIR"* ]]; then
	    # if yes, take the subdir
	    subdir=$(echo "$pkg_dir" | sed "s|$INPUT_DIR||")
	    # If subdir is not empty, adds subdir to pkg name
	    if [[ -n "$subdir" ]]; then
	        pkg_name="$subdir/$pkg_name"
	    else
	        pkg_name="$pkg_name"
	    fi
    else
	    pkg_name="$pkg_name"
    fi
    #echo "Processing: $pkg_name"
    #echo "pkg_name=$pkg_name"
    #echo "pkg_dir=$pkg_dir"

    # Execute command in container and saves output in tempfile1
    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_listentries "/workspace/$pkg_name" > ./tmpfile1
    #echo "Entries for $pkg_name"

    param_sfo_index=$(docker exec "$CONTAINER_NAME" grep "PARAM_SFO" /workspace/tmpfile1 | awk '{print $4}')
    #echo "PARAM_SFO index: $param_sfo_index"
    
    sfo_file="/workspace/${pkg_name}.sfo"
    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_extractentry "/workspace/$pkg_name" "$param_sfo_index" "$sfo_file"
    #echo "SFO extracted for $pkg_name."

    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core sfo_listentries "$sfo_file" > ./tmpfile
    #echo "Lista entries SFO ottenuta."

    category=$(docker exec "$CONTAINER_NAME" grep "CATEGORY" /workspace/tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    title_id=$(docker exec "$CONTAINER_NAME" grep "TITLE_ID" /workspace/tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    title=$(docker exec "$CONTAINER_NAME" grep "TITLE " /workspace/tmpfile | awk -F'=' '{print $2}' | sed 's/^ *//;s/ *$//')    
    version=$(docker exec "$CONTAINER_NAME" grep "APP_VER" /workspace/tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    release_tmp=$(docker exec "$CONTAINER_NAME" grep "PUBTOOLINFO" /workspace/tmpfile | grep -o "c_date=[0-9]*" | cut -d'=' -f2)
    release=$(echo "$release_tmp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\2-\3-\1/')
    size=$(stat -c %s "$pkg")
    content_id=$(docker exec "$CONTAINER_NAME" grep "CONTENT_ID" /workspace/tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    region="${content_id:0:1}"
    	if [[ "$region" == "J" ]]; then 
		region="JAP"
	elif [[ "$region" == "E" ]]; then
		region="EUR"
	elif [[ "$region" == "U" ]]; then
		region="USA"
	else 
		region="null"
	fi

    cover_url="$SERVER_URL"
    cover_url+="_img/$title_id.png"
    pkg_url="$SERVER_URL$pkg_name"
	if [[ -e "./_img/$title_id.PNG" ]]; then
	    coverexists=1
	else
	    coverexists=0
	    pic1_index=$(docker exec "$CONTAINER_NAME" grep 'ICON0_PNG' /workspace/tmpfile1 | awk '{print $4}')
	    #echo "pic1_index: $pic1_index"
	    # If ICON0 is empty, try PIC0
	    if [[ -z "$pic1_index" ]]; then
	        pic1_index=$(docker exec "$CONTAINER_NAME" grep 'PIC0_PNG' /workspace/tmpfile1 | awk '{print $4}')
	    fi
	fi

    echo "========================="
    # Create json entry for the element
    json_entry=$(jq -n --arg title_id "$title_id" --arg region "$region" --arg name "$title" --arg version "$version" \
                      --arg release "$release" --argjson size $size --arg cover_url "$cover_url" \
                      '{title_id: $title_id, region: $region, name: $name, version: $version, release: $release, size: $size, cover_url: $cover_url}')

    case "$category" in
        "gd") 
	    echo "CATEGORY: GAME"            
	    if [[ $coverexists -eq 0 ]]; then
  		docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_extractentry "/workspace/$pkg_name" "$pic1_index" "/workspace/_img/$title_id.PNG"
            	#echo "Extracted cover .$IMG_SUBDIR/$title_id.PNG"
            fi
	    update_json "$JSON_GAMES" "$pkg_url" "$json_entry"
	    cGames=$((cGames + 1))
            ;;
        "gp") 
            echo "CATEGORY: UPDATE"
            update_json "$JSON_UPDATES" "$pkg_url" "$json_entry"
            cUpd=$((cUpd + 1))
            ;;
        "ac") 
            echo "CATEGORY: DLC"
            update_json "$JSON_DLC" "$pkg_url" "$json_entry"
            cDlc=$((cDlc + 1))
            ;;
    esac

    echo "TITLE_ID: $title_id"
    echo "REGION: $region"
    echo "TITLE: $title"
    echo "VERSION: $version"
    echo "RELEASE: $release"
    echo "SIZE: $size"
    echo "PKG_URL: $pkg_url"
    echo "COVER_URL: $cover_url"

   #Remove tmp files
    docker exec "$CONTAINER_NAME" rm -f "$sfo_file" /workspace/tmpfile /workspace/tmpfile1

done < <(find "$INPUT_DIR" -type f -name "*.pkg")
#done

# Stops container
echo "Stopping container..."
docker stop "$CONTAINER_NAME"
echo "========================="
echo "PKGs added to jsons:"
echo "  GAMES: $cGames"
echo "  UPDATES: $cUpd"
echo "  DLCs: $cDlc"
echo ""
echo "Cleaning $JSON_GAMES..."
cleanup_json "$JSON_GAMES"
echo "Cleaning $JSON_UPDATES..."
cleanup_json "$JSON_UPDATES"
echo "Cleaning $JSON_DLC..."
cleanup_json "$JSON_DLC"
echo ""
echo "These are the URLs of the JSONs to set in your FPKGi configuration:" 
echo "$SERVER_URL$JSON_GAMES"
echo "$SERVER_URL$JSON_UPDATES"
echo "$SERVER_URL$JSON_DLC"
echo ""
echo "Processing completed."
