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

workspace="$(pwd)"

# ZUUL_PIPELINE indicates if this is daily, pre-release, or release build
# Build ID indicates specific date or tag
BLD="$(< $workspace/Build_ID)"

Flavor="Install"
DestFile="installer-$BLD.tar.gz"
Branch=master
DestDir="publish/$ZUUL_PIPELINE/$BLD"

set +x


# Clean up any previous label directories
rm -rf ./publish
rm -f $workspace/Versions*

# Check if we have already staged a build for this version of code
if ! /usr/local/bin/build-version-check.sh "$Branch" "$Flavor"
then
  # Declare success, but don't leave any files to be published
  echo "This build has been previously staged. Exiting."
  exit 0
fi

mkdir -p "./$DestDir" || exit 2

cp trafodion/install/installer*gz "$workspace/$DestDir/$DestFile"  || exit 2


cat trafodion/install/build-version.txt


# Declare success - make this the latest good build version to be uploaded
mv $workspace/Code_Versions $workspace/Versions-${Branch}-${ZUUL_PIPELINE}-${Flavor}.txt

exit 0
