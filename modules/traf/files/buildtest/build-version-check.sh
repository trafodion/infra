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

# Script to check the current code versions to the previous successful build
# This allows us to bail out and not post a new build with no code changes.

BRANCH="$1"
FLAVOR="$2"
PURPOSE="$3"

if [[ -z "$BRANCH" || -z "$FLAVOR" ]]
then
  echo "Error: Branch and Flavor arguments required to check previous build version"
  exit 11
fi

source /usr/local/bin/traf-functions.sh
log_banner

# retrieve previous build version
# file is created by the stage-traf.sh script 
# and posted by the traf-pub-* log publisher in jenkins_job_builder/config/traf.yaml

LOGLOC="http://traf-testlogs.esgyn.com/buildvers"
LOGFILE="Versions-${BRANCH}-${PURPOSE}-${FLAVOR}.txt"

cd $WORKSPACE
rm -f Previous_Version changes

echo "Retrieving Previous_Version file ($LOGFILE)"

wget --no-verbose -O Previous_Version $LOGLOC/$LOGFILE
rc=$?

if [[ $rc != 0 ]]
then
  echo "Error: Could not retrieve $LOGLOC/$LOGFILE"
  echo "    wget return code: $rc"
  echo "Continuing Build"
  exit 0
fi

# Compare Previous version to Current version
# Code_Versions is current file, created by git-prep-multi-repo.sh script

echo "Comparing Previous_Version to Code_Versions"

diff Previous_Version Code_Versions
rc=$?

if [[ $rc == 0 ]]
then
  echo "*****************************"
  echo "Code version is identical to previous successful build."
  cat Code_Versions
  echo "*****************************"
  exit 1
else
  echo "Code changes detected."
  cat Previous_Version | while read repo commit comments
  do
    newcommit=$(grep ^$repo $WORKSPACE/Code_Versions | cut -d " " -f 2)
    cd $WORKSPACE/trafodion
    git log ${commit}..${newcommit} > $WORKSPACE/changes
  done
  exit 0
fi
