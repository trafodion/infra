#!/bin/bash

source "/usr/local/bin/traf-functions.sh"

#===================
# Define variables
#===================
export PRG_NAME=`basename $0`

# functions
PROGRAM_HELP() {
set +x
    echo "
    Usage: $PRG_NAME <Trafodion_PATH>

    Options :
        <Trafodion_PATH>        Location where Trafodion is is installed

    NOTE: If relative PATHS are used for <Trafodion_PATH>, make sure the relative paths
          are specified from the same starting directory.

    Examples :
        $PRG_NAME "trafodion/core"              # stops trafodion using relative paths
        $PRG_NAME "/home/trafodion/core"        # stops trafodion using absolute paths

"
set -x
}


# main
set -x
if [ -z "$WORKSPACE" ]; then
    export WORKSPACE=$(pwd)
fi

# assume Trafodion env is already sourced in if there are no input parameters
# otherwise make sure there is only 1 input parameter and that the input parameter
# is a directory and source in Trafodion env
if [ $# -eq 1 -a -d "$1" ]; then
    cd "$WORKSPACE"
    cd "$1"
    source_env
elif [ $# -gt 1 ]; then
    echo "ERROR: Incorrect number of input parameters passed to ${PRG_NAME}"
    PROGRAM_HELP
    exit 1
fi

sqstop
echo "Return code $?"
sudo /usr/local/bin/hbase-sudo.sh stop
echo "Return code $?"

