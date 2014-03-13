#!/bin/sh 

source /usr/local/bin/traf-functions.sh

#parameter is build flavor: release or debug
FLAVOR=$1

#optional parameter for build target: e.g., "package"
TARGET="all"
if [[ -n "$2" ]]
then
  TARGET="$2"
fi

workspace="$(pwd)"

set -x

cd trafodion/core/sqf

source_env $FLAVOR
cd ..


# Use Zuul / Jenkins values
VER="$(git describe --long --tags --dirty --always)${ZUUL_BRANCH}"
export PV_BUILDID=${VER}_Bld${BUILD_NUMBER}
export PV_DATE=$(echo ${BUILD_ID} | sed 's/-//g')

make $TARGET > Make.log 2>&1
rc=$?

cd $workspace

exit $rc
