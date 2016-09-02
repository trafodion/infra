#!/bin/sh
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
# target branch
Branch="$3"
# target OS
OSver="$4"


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
  FileSuffix="-debug-$BLD-incubating-bin.tar.gz"
else
  FileSuffix="-$BLD-incubating-bin.tar.gz"
fi

# Destination dir should be daily, pre-release, or release even if build
# has an additional suffix, e.g. -stable

# side-branch build?
if [[ ${BLD_PURPOSE} =~ ^daily- ]]
then
  DestDir="publish/daily/${BLD}-${Branch}-$Flavor"
else
  if [[ ${BLD_PURPOSE} == daily ]]
  then
    DestDir="publish/daily/${BLD}-$Flavor"
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

# Check if we have already staged a build for this version of code
if ! /usr/local/bin/build-version-check.sh "$Branch" "${OSver}-$Flavor" "$BLD_PURPOSE"
then
  # Declare success, but don't leave any files to be published
  echo "This build has been previously staged. Exiting."
  exit 0
elif [[ ${BLD_PURPOSE} =~ ^daily ]]
then
  # Publish change-logs, but only for daily* (including side-branches)
  #   change logs for release builds would be too large 
  #    ("No, there is too much. Let me sum up.")
  cd $workspace
  if [[ -s changes ]] # non-empty
  then
    mv changes $DestDir/changes-${BLD}.txt
  fi
fi

cd $workspace

# save record of git commit ID
cp ./trafodion/build-version.txt ./$DestDir/

# src
srcpkg=$(ls ./trafodion/distribution/*-src.tar* 2>/dev/null)
if [[ -n $srcpkg ]]
then
  cp $srcpkg ./$DestDir/
fi

# installer
install=$(ls ./trafodion/install/installer*gz ./trafodion/distribution/*installer*gz 2>/dev/null)
if [[ $(basename $install) =~ ^apache- ]]
then
  cp $install ./$DestDir/  || exit 2
else
  cp $install ./$DestDir/apache-trafodion-installer-$BLD-incubating-bin.tar.gz  || exit 2
fi

# clients tarfile
client=$(ls ./trafodion/distribution/*trafodion_clients-*)
if [[ $(basename $client) =~ ^apache- ]]
then
  cp $client ./$DestDir/  || exit 2
else
  cp $client ./$DestDir/apache-trafodion-clients$FileSuffix  || exit 2
fi


# core and dcs in server tarfile
server=$(ls ./trafodion/distribution/*trafodion_server-*)
if [[ $(basename $server) =~ ^apache- ]]
then
  cp $server ./$DestDir/  || exit 2
else
  mkdir -p "./collect" || exit 2
  cp $server collect/  || exit 2
  # rest added in 1.1 release
  rest=$(ls trafodion/distribution/rest-*gz 2>/dev/null)
  if [[ -f "$rest" ]]
  then
    rbase=$(basename $rest .tar.gz)
    cp $rest collect/${rbase}.tgz  || exit 2
  fi

  # change suffix from tar.gz to tgz
  dcs=$(ls trafodion/distribution/dcs-[0-9]*gz)
  dcsbase=$(basename $dcs .tar.gz)
  cp $dcs collect/${dcsbase}.tgz  || exit 2

  cat trafodion/build-version.txt >> collect/build-version.txt
  cat collect/build-version.txt

  # publish (DestDir) dir will be uploaded by scp rules in jenkins job
  cd ./collect
  tar czvf "$workspace/$DestDir/apache-trafodion$FileSuffix" *
  rcC=$?

  if [[ $rcC != 0 ]]
  then
    exit 2
  fi
fi

cd $workspace/$DestDir
for f in $(/bin/ls *gz)
do
  md5sum $f > ${f}.md5
  sha1sum $f > ${f}.sha
done

# Declare success - make this the latest good build 
# Versions* file will be uploaded by scp rules in jenkins job
mv $workspace/Code_Versions $workspace/Versions-${Branch}-${BLD_PURPOSE}-${OSver}-${Flavor}.txt

exit 0
