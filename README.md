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

Feel free to use it and/or improve it!

Cheers!
superuser866
