# ps4-fpkgi-json
This is a bash script that automate the creation of the jsons files for using with PS4 FPKGI.

The script uses official OpenOrbis Docker container (openorbisofficial/toolchain) to extract info and cover from pkg files. (Container is created with name "openorbis" and removed at the end. 
It recursively scans the input directory for .pkg files, then it extracts all the needed informations, the cover png and creates in the same directory the three jsons

GAMES.json

UPDATES.json

DLC.json

Then it reads the jsons searching for the files on the filesystem and removes invalid records.
You can schedule it to automatically add your new pkgs to the collection and/or removes the ones you deleted.

It is mandatory that the sh script resides into the same root directory where your pkgs are. 
Also the jsons will be created in the same directory.
For example: 
  I have my pkgs collection on this directory /nfs/PS4/Games/ which corresponds to my web server URL: http://test.lan/PS4/
  so the commands will be:

  cd /nfs/PS4/Games/ 
  
  ./ps4-fpkgi-json.sh http://test.lan/PS4/

If for any reason the script crashes with container running, you may have to issue the command "docker stop openorbis" to stop and remove it).
If for any reason one of the JSONs becomes corrupted, you will have to delete it or the script will fail to read and write it. 

**Requirements**:
- docker
- jq (to work with json files)

**Fixes**
- Fixed Version extraction, previously it reported everytime 01.00
- Fixed Cover extraction, previously was extracting background image instead of icon
- Added Region extraction
- Added "DATA" node to the jsons to improve compatibilty with FPKGi versions
- Fixed extension of cover files

# fpkgi-service-monitor.sh

You can use this batch to automatically update fpkgi json files when you put a new .pkg in the Games directory.
The service monitor uses inotifywait to check when you put a new .pkg file in the Game directory and creates a temporary file.
The updater searches the temporary file and if found it triggers the json update after the eventual GRACE_PERIOD (in seconds, just to allow eventual transfer to complete). 

1) Put the tho .sh files in one directory for example /opt/fpkgi-updater
2) Edit configuration in the first line of the fpkgi-service-monitor.sh:
   
   #Directory to monitor
   
   MONITOR_DIR="/nfs/PS4/Games"

   #Check file to verify successful mount
   
   CHECK_FILE="$MONITOR_DIR/mount.chk" 

4) Create the CHECK_FILE (es.: touch /nfs/PS4/Games/mount.chk")

5) Edit configuration in the first line of the fpkgi-update-json.sh

   UPDATE_URL="http://odin.lan/PS4/"

   MONITOR_DIR="/nfs/PS4/Games"

   GRACE_PERIOD=60

7) Schedule the service monitor at boot time:

   #FPKGI SERVICE MONITOR

   @reboot /opt/fpkgi-service-monitor.sh >> /opt/fpkgi-service-monitor.log 2>&1

8) Schedule the updater every X minutes as you wish

   #FPKGI UPDATE JSON ON REQUEST

   */1 * * * * /opt/fpkgi-update-json.sh >> /opt/fpkgi-update-json.log 2>&1

Feel free to use it and/or improve it!

Cheers!
superuser866
