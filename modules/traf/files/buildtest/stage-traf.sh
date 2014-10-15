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

workspace="$(pwd)"

# ZUUL_PIPELINE indicates if this is daily, pre-release, or release build
# If we are run from jenkins, not Zuul, then default to daily
ZUUL_PIPELINE=${ZUUL_PIPELINE:-daily}

# Build ID indicates specific date or tag
BLD="$(< $workspace/Build_ID)"

# flavor of build
Flavor="$1"
if [[ "$Flavor" == "debug" ]]
then
  FileSuffix="_debug-$BLD.tar.gz"
else
  FileSuffix="-$BLD.tar.gz"
fi

# side-branch build?
if [[ ${ZUUL_PIPELINE} =~ ^daily- ]]
then
  Branch=${ZUUL_PIPELINE#daily-}
  DestDir="publish/daily/$BLD"
else
  Branch=master
  DestDir="publish/$ZUUL_PIPELINE/$BLD"
fi


set -x


# Clean up any previous label directories
rm -rf ./collect ./publish
rm -f $workspace/Versions*

# Check if we have already staged a build for this version of code
if ! /usr/local/bin/build-version-check.sh "$Branch" "$Flavor"
then
  # Declare success, but don't leave any files to be published
  echo "This build has been previously staged. Exiting."
  exit 0
fi

# maven deploy of T2 and T4 drivers  -- non-debug only
if [[ "$Flavor" == "release" ]]
then
  PubRepo="scp://mvnrepo.trafodion.org/srv/static/mvnrepo"

  # official release goes to main repo
  # intermediate builds goes to dev location
  if [[ $BLD =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    org="org.trafodion"
  else
    org="org.trafodion-dev"
  fi

  cd $workspace/trafodion/core/conn/jdbc_type2
  cp /usr/local/bin/wagon.xml ./pom.xml
  mvn deploy:deploy-file  \
       -Durl="$PubRepo" -Dfile=./dist/jdbcT2.jar \
       -DgroupId=${org}.jdbc.t2.T2Driver -DartifactId=t2driver \
       -Dversion="$BLD" -DgeneratePom.description="Trafodion JDBC Type2"
  rcA=$?

  cd $workspace/trafodion/core/conn/jdbc_type4
  cp /usr/local/bin/wagon.xml ./pom.xml
  mvn deploy:deploy-file  \
       -Durl="$PubRepo" -Dfile=./temp/deploy/lib/jdbcT4.jar \
       -DgroupId=${org}.jdbc.t4.T4Driver -DartifactId=t4driver \
       -Dversion="$BLD" -DgeneratePom.description="Trafodion JDBC Type4"
  rcB=$?
else
  rcA=0
  rcB=0
fi

cd $workspace
# create server/clients tarballs
mkdir -p "./$DestDir" || exit 2
mkdir -p "./collect" || exit 2

# clients tarfile
cp ./trafodion/core/trafodion_clients-*.tgz ./$DestDir/clients$FileSuffix  || exit 2

# core and dcs in server tarfile
cp trafodion/core/trafodion_server-*.tgz collect/  || exit 2

# change suffix from tar.gz to tgz
dcsbase=$(basename trafodion/dcs/target/dcs*gz .tar.gz)
cp trafodion/dcs/target/dcs*gz collect/${dcsbase}.tgz  || exit 2

for repo in core dcs 
do
  cat trafodion/$repo/build-version.txt >> collect/build-version.txt
  echo "==========================" >> collect/build-version.txt
  echo "" >> collect/build-version.txt
done
cat collect/build-version.txt

# publish (DestDir) dir will be uploaded by scp rules in jenkins job
cd ./collect
sha512sum * > sha512.txt
tar czvf "$workspace/$DestDir/trafodion$FileSuffix" *
rcC=$?

if [[ $rcA != 0 || $rcB != 0 || $rcC != 0 ]]
then
  exit 2
fi

# Declare success - make this the latest good build 
# Versions* file will be uploaded by scp rules in jenkins job
mv $workspace/Code_Versions $workspace/Versions-${Branch}-${ZUUL_PIPELINE}-${Flavor}.txt

exit 0
