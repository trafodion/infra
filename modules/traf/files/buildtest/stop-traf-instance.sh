#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2014 Hewlett-Packard Development Company, L.P.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# @@@ END COPYRIGHT @@@

source "/usr/local/bin/traf-functions.sh"
log_banner

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

# assume Trafodion env is already sourced in if there are no input parameters
# otherwise make sure there is only 1 input parameter and that the input parameter
# is a directory and source in Trafodion env
if [ $# -eq 1 -a -d "$1" ]; then
    cd "$WORKSPACE"
    cd "$1"
    source_env build
elif [ $# -gt 1 ]; then
    echo "ERROR: Incorrect number of input parameters passed to ${PRG_NAME}"
    PROGRAM_HELP
    exit 1
fi

timeout 5m sqstop
ret=$?
if [[ $ret == 124 ]]
then
  echo "ERROR: sqstop timed-out -- see bug 1324370"
else
  echo "Return code $ret"
fi

sudo /usr/local/bin/hbase-sudo.sh stop
echo "Return code $?"

