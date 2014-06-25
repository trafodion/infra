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

# flavor of build
Flavor="$1"
if [[ "$Flavor" == "debug" ]]
then
  DestFile="trafodion_debug-$BLD.tar.gz"
else
  DestFile="trafodion-$BLD.tar.gz"
fi

DestDir="publish/$ZUUL_PIPELINE/$BLD"

set +x


# Clean up any previous label directories
rm -rf ./collect ./publish


mkdir -p "./$DestDir" || exit 2
mkdir -p "./collect" || exit 2

cp trafodion/core/traf*.tgz collect/  || exit 2

cp trafodion/dcs/target/dcs*gz collect/  || exit 2

cp trafodion/install/installer*gz collect/  || exit 2

for repo in core dcs install
do
  cat trafodion/$repo/build-version.txt >> collect/build-version.txt
  echo "==========================" >> collect/build-version.txt
  echo "" >> collect/build-version.txt
done
cat collect/build-version.txt


cd ./collect
sha512sum * > sha512.txt
tar czvf "$workspace/$DestDir/$DestFile" *

# Declare success - make this the latest good build version to be uploaded
# hard-code master branch for now
mv $workspace/Code_Versions $workspace/Versions-master-${ZUUL_PIPELINE}-${Flavor}.txt

exit 0
