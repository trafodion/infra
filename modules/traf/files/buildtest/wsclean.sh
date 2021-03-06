#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2014-2015 Hewlett-Packard Development Company, L.P.
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

# modes:
#   build - jenkins user only, git repo build trees
#   test - jenkins/tinstall/trafodion users, install/test workspace
#   <none> - legacy mode is build and install/test in same workspace
mode="$1"

if [[ "$mode" != "build" ]]
then
  # delete dirs owned by non-jenkins users & run puppet
  sudo -n /usr/local/bin/wsclean-sudo.sh "$WORKSPACE"
else
  # just do the puppet update on build system
  sudo -n /usr/bin/puppet agent --test --no-report --color false
fi

if [[ "$mode" == "test" ]]
then
  # delete everything
  rm -rf $WORKSPACE/*
else
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
fi

echo "Post-Cleanup: ls $WORKSPACE"
echo "---------------------"
ls $WORKSPACE
echo "---------------------"

# do not raise an error if anything failed
# don't want to kill a job over clean-up failure
exit 0
