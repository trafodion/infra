#!/bin/bash -e
# -e option: Error out on any command/pipeline error
#
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

rm -f Git-Prep.log

# Optional over-ride branch
# Useful to test cross-branch compatibility
if [[ $1 == "-b" ]]
then
  TargetBranch="$2"
  shift 2
else
  TargetBranch="$ghprbTargetBranch"
fi

repo="$1"

GIT_ORIGIN="https://github.com"

if [[ -z "$sha1" ]]
then
    if [[ -n $BRANCH ]]  # direct jenkins parameter
    then
      TargetBranch="$BRANCH"
    else
      TargetBranch="master"
    fi

    echo "******************************************"
    echo "Warning: Job not triggered by code change."
    echo "         Building latest on $TargetBranch branch."
    echo "******************************************"
    sha1=$TargetBranch
fi

if [[ ! -z "$ghprbPullLink" ]]
then
    echo "Triggered by: $ghprbPullLink"
fi

if [[ -z "$repo" ]]
then
    echo "Argument required -- repository list"
    exit 1
fi

export GIT_SSL_NO_VERIFY=1

workspace="$(pwd)"

echo "Using reference: $sha1"

# Build ID across repos
BLDInfo="$BUILD_TYPE $BUILD_ID"
rm -f "$workspace/Build_ID" "$workspace/Code_Versions"

## To-Do: tag builds
#if [[ $ZUUL_REF =~ ^refs/tags/ ]]
#then
#BID="${ZUUL_REF#refs/tags/}"
#echo "Building for tag: $BID"
if [[ -n "$ghprbPullId" ]]
then
  BID="PR${ghprbPullId}-$ghprbActualCommit"
  echo "Building for pull request PRID-commitID: $BID"
else
  BID="$(date -u +%Y%m%d_%H%M)"
  echo "Building for date: $BID"
fi

# Leave file around for later job steps
echo "$BID" > "$workspace/Build_ID"

# Save stderr/stdout in log file
echo "Saving output to Git-Prep.log"
set -x
exec &>Git-Prep.log


cd "$workspace"
# keep same naming scheme even if source repoi named differently
if [[ ! -e ./trafodion ]]
then
   mkdir -p ./trafodion
fi

cd ./trafodion

if [[ ! -e .git ]]
then
    rm -fr .[^.]* *
	git clone $GIT_ORIGIN/$repo .
fi
# Make sure we are pointing to right repo and fetch latest
git remote set-url origin $GIT_ORIGIN/$repo
if ! git remote update --prune
then
    echo "The remote update failed, so garbage collecting before trying again."
    git gc
    git remote update --prune
fi

# fetch Branch
git fetch $GIT_ORIGIN/$repo +refs/heads/${TargetBranch}:refs/remotes/origin/${TargetBranch}
# fetch pull requests
git fetch $GIT_ORIGIN/$repo +refs/pull/*:refs/remotes/origin/pr/*
if git checkout -f $sha1
then
  git reset --hard HEAD
else
  echo "Could not find $sha1 for $repo"
  exit 3
fi

git clean -x -f -d -q

# leave some version info around
echo "$BLDInfo" > build-version.txt
echo "$repo" >> build-version.txt
#if [[ $ref =~ ^refs/tags/ ]]
#    then
#      echo "Tag:    ${ref#refs/tags/}" >> build-version.txt
#    else
#      echo "Ref:    $ref" >> build-version.txt
#    fi
echo "Commit: $(git log -n1 --format=oneline)" >> build-version.txt
echo "Desc:   $(git describe --long --tags --dirty --always)" >> build-version.txt
# exclude this file from git status so we don't contaminate the environment.
# check-git-status.sh script will verify no extraneous files are created.
if ! grep -q build-version.txt .git/info/exclude
then
   echo "/build-version.txt" >> .git/info/exclude
fi

#combined list -- allows check for change from previous build
echo "$repo $(git log -n1 --format=oneline)" >> "$workspace/Code_Versions"

exit 0
