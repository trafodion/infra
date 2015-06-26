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


# Find currently running job working on same Pull Req ID
# If found, abort it

# Must be on jenkins master node, to access user/password for abort action
# Must be root to access user/password info

# Note: we depend on single jenkins server to search. Algorithm needs to change if 
#   scaled to multiple jenkins servers.


# job name (jenkins "project") of top-level job
PROJ_NAME="Check-PR"

# jenkins server data cmd - jenkins provides JENKINS_URL
API="curl -s $JENKINS_URL/job/$PROJ_NAME"

# Loop forever, in case server is not responding
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

  # Search from newest
  Bld=$Latest
  while (( $Bld > $Earliest ))
  do
    # make sure we don't cancel ourself
    if (( $Bld == $BUILD_NUMBER ))
    then
      Bld=$(( $Bld - 1))
      continue
    fi
    pr=$($API/$Bld/api/json | 
	  jq -r '.actions[].parameters[] | select(.name == "ghprbPullId").value' 2>/dev/null)
    if [[ $pr == $ghprbPullId ]]
    then
      MyBuild=$Bld
      break 2
    fi
    Bld=$(( $Bld - 1))
  done
  echo "Did not find any prior $PROJ_NAME job for Pull Request $ghprbPullId"
  exit 0
done

echo "Prior $PROJ_NAME job for Pull Request $ghprbPullId"
echo "Build: $JENKINS_URL/job/$PROJ_NAME/$MyBuild"

# Found a prior job for our PR, now check if it is still running
if [[ "$($API/$MyBuild/api/json | jq -r '.building' 2>/dev/null)" == "false" ]]
then
  echo "Job is no longer running"
  exit 0
fi

echo "Aborting prior build for this pull request"

USER=$(sed -n '/^user=/s/user=//p' /etc/jenkins_jobs/jenkins_jobs.ini)
PW=$(sed -n '/^password=/s/password=//p' /etc/jenkins_jobs/jenkins_jobs.ini)

curl -X POST -s -u ${USER}:$PW $JENKINS_URL/job/$PROJ_NAME/$MyBuild/stop

exit 0
