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

source /usr/local/bin/traf-functions.sh
log_banner

rc=0   #so far, so good

git_dir="$1"

if [[ -z $git_dir ]]
then
  echo "Error: git directory required"
  exit 1
fi

cd $git_dir || exit 1

modified=$(git ls-files -m | wc -l)
unignored=$(git ls-files -o --exclude-standard | wc -l)

if [[ $modified != 0 ]]
then
  echo "Error: Build modified $modified versioned file(s)"
  echo "==========="
  git ls-files -m
  echo "==========="
  rc=2
else
  echo "Success: Build modified 0 versioned files"
fi
if [[ $unignored != 0 ]]
then
  echo "Error: Build created $unignored untracked file(s)"
  echo "       Update .gitignore files"
  echo "==========="
  git ls-files -o --exclude-standard
  echo "==========="
  rc=2
else
  echo "Success: Build created 0 untracked files"
fi

if [[ -x sqf/build-scripts/find-abs-dlls ]]
then
  # Check for use of absolute files as DLLs
  sqf/build-scripts/find-abs-dlls
  absrefs=$?
  if [[ $absrefs != 0 ]]
    then
    echo "Error: Build created $absrefs dll references to absolute filenames"
    rc=3
  else
    echo "Success: Build created 0 dll references to absolute filenames"
  fi
fi

# Check sqvers output - core repo only
if [[ -x sqf/sqvers ]]
then
  source_env build
  sqvers  2>&1 | grep -q 'missing version'
  if [[ $? == 0 ]]; then
     echo "Error: version info is missing (sqvers)"
     sqvers  2>&1 | grep 'missing version'
     rc=4
  else
     echo "Success: sqvers finds no missing version info"
  fi
fi


exit $rc
