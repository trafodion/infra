#!/bin/bash 

# Script to check the current code versions to the previous successful build
# This allows us to bail out and not post a new build with no code changes.

BRANCH="$1"
FLAVOR="$2"

if [[ -z "$BRANCH" || -z "$FLAVOR" ]]
then
  echo "Error: Branch and Flavor arguments required to check previous build version"
  exit 11
fi

# retrieve previous build version
# file is created by the stage-traf.sh script 
# and posted by the traf-pub-* log publisher in jenkins_job_builder/config/traf.yaml

LOGLOC="http://logs.trafodion.org/buildvers"
LOGFILE="Versions-${BRANCH}-${ZUUL_PIPELINE}-${FLAVOR}.txt"

rm -f Previous_Version

echo "Retrieving Previous_Version file ($LOGFILE)"

wget -O Previous_Version $LOGLOC/$LOGFILE
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
  exit 0
fi
