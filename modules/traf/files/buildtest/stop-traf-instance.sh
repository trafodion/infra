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

# no arguments needed


# main
set -x

source_env run

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

