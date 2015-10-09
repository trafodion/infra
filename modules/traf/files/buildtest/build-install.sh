#!/bin/sh -e
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

# Build ID indicates specific date or tag
BLD="$(< $WORKSPACE/Build_ID)"

# trace
set -x

cd $WORKSPACE/trafodion/install || exit 2

# Save build version info into package
cp ../build-version.txt ./installer/build-version-${BLD}.txt
# exclude this file from git status so we don't contaminate the environment.
# check-git-status.sh script will verify no extraneous files are created.
if ! grep -q build-version-${BLD}.txt ../.git/info/exclude
then
  echo "build-version-${BLD}.txt" >> ../.git/info/exclude
fi


make all

exit $?
