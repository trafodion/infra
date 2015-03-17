#!/bin/sh
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

WORKSPACE="$1"

if [[ -z "$WORKSPACE" ]]
then
  echo "WORKSPACE variable not set"
  exit 1
fi


source /usr/local/bin/traf-functions.sh
log_banner

sudo -n -u tinstall rm -rf $WORKSPACE/traf_inst 

# trafodion id may be removed by trafodion uninstall
# root will delete these
rm -rf $WORKSPACE/phx_test_run $WORKSPACE/traf_run
rm -rf $WORKSPACE/rundir $WORKSPACE/sql-regress-logs

# clean trafodion previous versions that installer generates
# to prevent using all root disk space
rm -rf /usr/lib/trafodion
