#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2015 Hewlett-Packard Development Company, L.P.
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


# Find job with build artifacts that matches our job
# based on:
#   ZUUL_CHANGES
#     or
#   ZUUL_REF
#     or
#   ZUUL_PIPELINE and date portion of BUILD_ID
#
# Waits on build job to be complete.
#
# On success, leaves a bld.properties file that can be used
# to inject environment variables to later build steps, specifically
# to provide parameters to copy artifacts from build job.

# Note: we depend on single jenkins server to search. Algorithm needs to change if 
#   zuul is scaled to multiple jenkins servers.

if [[ -z "$1" ]]
then
  echo "Error: job name (jenkins 'project' name) required"
  exit 1
fi

# job name (jenkins "project") of Build providing artifacts
BLD_PROJ_NAME="$1"

# jenkins server data cmd - jenkins provides JENKINS_URL
API="curl -s $JENKINS_URL/job/$BLD_PROJ_NAME"

# Loop forever, in case server is not responding or we are waiting for
# gearman to start our build in jenkins
while true
do
  Latest=$($API/api/json | jq -r '.lastBuild.number' 2>/dev/null)
  Earliest=$($API/api/json | jq -r '.firstBuild.number' 2>/dev/null)
  if [[ -z $Latest || -z $Earliest ]]  # did not get good response from server
  then
    echo "Waiting for jenkins server response (sleepint 2 min)"
    sleep 120
    continue
  fi

  # Search from newest for our build
  Bld=$Latest
  while (( $Bld >= $Earliest ))
  do
    # are we looking for a specific change-set build?
    if [[ -n "$ZUUL_CHANGES" ]]
    then
      bld_chgs=$($API/$Bld/api/json | 
	  jq -r '.actions[].parameters[] | select(.name == "ZUUL_CHANGES").value' 2>/dev/null)
      if [[ $bld_chgs == $ZUUL_CHANGES ]]
      then
        MyBuild=$Bld
	break 2
      fi
    # or do we have a tagged build?
    elif [[ -n "$ZUUL_REF" ]]
    then
      bld_ref=$($API/$Bld/api/json | 
	  jq -r '.actions[].parameters[] | select(.name == "ZUUL_REF").value' 2>/dev/null)
      if [[ $bld_ref == $ZUUL_REF ]]
      then
        MyBuild=$Bld
	break 2
      fi
    # otherwise look for our pipeline (e.g. daily) and date
    # assumes both build and test job got initiated on same date
    else
      bld_pipe=$($API/$Bld/api/json | 
	  jq -r '.actions[].parameters[] | select(.name == "ZUUL_PIPELINE").value' 2>/dev/null)
      if [[ $bld_pipe == $ZUUL_PIPELINE ]]
      then
        bld_date=$($API/$Bld/injectedEnvVars/api/json | jq -r '.envMap.BUILD_ID' 2>/dev/null)
	if [[ ${bld_date%_*} == ${BUILD_ID%_*} ]]
	then
          MyBuild=$Bld
	  break 2
	fi
      fi
    fi

    Bld=$(( $Bld - 1))
  done
  echo "Did not find our build. Sleeping 2 minutes to try again."
  sleep 120 # try again in a couple minutes
done

echo "Build: $JENKINS_URL/job/$BLD_PROJ_NAME/$MyBuild"

# Found our build job, now wait for it to be completed
# Use test != false, to avoid false positive on connectivity issue
while [[ "$($API/$MyBuild/api/json | jq -r '.building' 2>/dev/null)" != "false" ]]
do
  echo "Build job still running. Waiting 2 minutes."
  sleep 120
done

bld_result=$($API/$MyBuild/api/json | jq -r '.result' 2>/dev/null)
while [[ -z $bld_result ]]
do
  sleep 3
  echo "Rechecking build result"
  bld_result=$($API/$MyBuild/api/json | jq -r '.result' 2>/dev/null)
done

if [[ $bld_result == "SUCCESS" ]]
then
  echo "Found successful build: $MyBuild"
  echo "BLD_PROJ = $BLD_PROJ_NAME" > bld.properties
  echo "BLD_NUM = $MyBuild" >> bld.properties
  exit 0
else
  echo "Found $bld_result build: $MyBuild"
  exit 1
fi
