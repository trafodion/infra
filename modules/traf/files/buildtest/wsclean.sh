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

source /usr/local/bin/traf-functions.sh
log_banner

# delete dirs owned by non-jenkins users
sudo -n /usr/local/bin/wsclean-sudo.sh "$WORKSPACE"

# Delete all dirs except trafodion (git workspaces)
# Without -a we should not get "." directories, but double check
# Recursive delete of .. is bad
/bin/ls $WORKSPACE | while read dir
do
  if [[ ! $dir =~ ^trafodion$ && ! $dir =~ \\.* ]]
  then
    rm -rf $WORKSPACE/$dir
  fi
done
echo "Post-Cleanup: ls $WORKSPACE"
ls $WORKSPACE

# do not raise an error if anything failed
# don't want to kill a job over clean-up failure
exit 0
