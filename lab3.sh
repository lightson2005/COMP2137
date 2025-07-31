#!/bin/bash
VERBOSE=""
[[ "$1" == "-verbose" ]] && VERBOSE="-verbose"
SCRIPT="configure-host.sh"
SERVER1="remoteadmin@server1-mgmt"
SERVER2="remoteadmin@server2-mgmt"
REMOTE_PATH="/root/$SCRIPT"
scp $SCRIPT $SERVER1:$REMOTE_PATH || { echo "Failed to copy to server1"; exit 1; }
ssh $SERVER1 "$REMOTE_PATH -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4 $VERBOSE" || { echo "Failed to run on server1"; exit 1; }
scp $SCRIPT $SERVER2:$REMOTE_PATH || { echo "Failed to copy to server2"; exit 1; }
ssh $SERVER2 "$REMOTE_PATH -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3 $VERBOSE" || { echo "Failed to run on server2"; exit 1; }
sudo ./$SCRIPT -hostentry loghost 192.168.16.3 $VERBOSE
sudo ./$SCRIPT -hostentry webhost 192.168.16.4 $VERBOSE
echo "Done."
