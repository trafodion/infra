#!/bin/sh -e
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

# Publish/Stage builds only for daily builds
# 

# flavor of build
Flavor="$1"
# type of build
BLD_PURPOSE="$2"


if [[ -z $BLD_PURPOSE ]]
then
  echo "stage-traf: Manual build. Skipping publishing"
  exit 0
elif [[ $BLD_PURPOSE =~ ^release|^pre-release|^daily ]]
then
  echo "stage-traf: Continue publishing for $BLD_PURPOSE build"
else # all other builds: check
  echo "stage-traf: Skipping publishing for $BLD_PURPOSE build"
  exit 0
fi


source /usr/local/bin/traf-functions.sh
log_banner

workspace="$(pwd)"

# Build ID indicates specific date or tag
BLD="$(< $workspace/Build_ID)"

if [[ "$Flavor" == "debug" ]]
then
  FileSuffix="_debug-$BLD.tar.gz"
else
  FileSuffix="-$BLD.tar.gz"
fi

# Destination dir should be daily, pre-release, or release even if build
# has an additional suffix, e.g. -stable

# side-branch build?
if [[ ${BLD_PURPOSE} =~ ^daily- ]]
then
  Branch=${BLD_PURPOSE#daily-}
  DestDir="publish/daily/$BLD"
else
  Branch=master  # time based on master, or label-specific
  if [[ ${BLD_PURPOSE} == daily ]]
  then
    DestDir="publish/daily/$BLD"
  elif [[ ${BLD_PURPOSE} =~ ^release ]]
  then
    DestDir="publish/release/$BLD"
  elif [[ ${BLD_PURPOSE} =~ ^pre-release ]]
  then
    DestDir="publish/pre-release/$BLD"
  fi
fi


set -x


# Clean up any previous label directories
rm -rf ./collect ./publish
rm -f $workspace/Versions*

mkdir -p "./$DestDir" || exit 2
mkdir -p "./collect" || exit 2

# Check if we have already staged a build for this version of code
if ! /usr/local/bin/build-version-check.sh "$Branch" "$Flavor" "$BLD_PURPOSE"
then
  # Declare success, but don't leave any files to be published
  echo "This build has been previously staged. Exiting."
  exit 0
elif [[ "$Flavor" == "release" && ${BLD_PURPOSE} =~ ^daily ]]
then
  # Publish change-logs, but only for release flavor, daily* (including side-branches)
  #   debug flavor should be identical
  #   change logs for release builds would be too large 
  #    ("No, there is too much. Let me sum up.")
  cd $workspace
  for file in changes-core changes-dcs
  do
    if [[ -s $file ]] # non-empty
    then
      mv $file $DestDir/${file}-${BLD}.txt
    fi
  done
fi

cd $workspace

# installer
cp ./trafodion/install/installer*gz ./$DestDir/installer-$BLD.tar.gz  || exit 2

# clients tarfile
client=$(ls ./trafodion/core/trafodion_clients-*.tgz ./trafodion/distribution/trafodion_clients-*.tgz)
cp $client ./$DestDir/clients$FileSuffix  || exit 2

# core and dcs in server tarfile
server=$(ls ./trafodion/core/trafodion_server-*.tgz ./trafodion/distribution/trafodion_server-*.tgz)
cp $server collect/  || exit 2
# rest added in 1.1 release
rest=$(ls trafodion/core/rest/target/rest-*gz trafodion/distribution/rest-*gz 2>/dev/null)
if [[ -f "$rest" ]]
then
  rbase=$(basename $rest .tar.gz)
  cp $rest collect/${rbase}.tgz  || exit 2
fi

# change suffix from tar.gz to tgz
dcs=$(ls trafodion/dcs/target/dcs*gz trafodion/distribution/dcs*gz)
dcsbase=$(basename $dcs .tar.gz)
cp $dcs collect/${dcsbase}.tgz  || exit 2

cat trafodion/build-version.txt >> collect/build-version.txt
cat collect/build-version.txt

# publish (DestDir) dir will be uploaded by scp rules in jenkins job
cd ./collect
sha512sum * > sha512.txt
tar czvf "$workspace/$DestDir/trafodion$FileSuffix" *
rcC=$?

if [[ $rcC != 0 ]]
then
  exit 2
fi

# Declare success - make this the latest good build 
# Versions* file will be uploaded by scp rules in jenkins job
mv $workspace/Code_Versions $workspace/Versions-${Branch}-${BLD_PURPOSE}-${Flavor}.txt

exit 0
