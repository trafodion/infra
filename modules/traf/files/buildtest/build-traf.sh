#!/bin/sh
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

#parameter is build flavor: release or debug
FLAVOR=$1

#optional parameter for build target: e.g., "package"
TARGET="all"
if [[ -n "$2" ]]
then
  shift 1
  TARGET="$*"
fi

set -x


source_env -v build $FLAVOR

cd trafodion/core

# Pull latest posted Win-ODBC build if available
WINLOC="http://traf-testlogs.esgyn.com/winbld"

mkdir -p conn/clients

# parse from html listing and reverse sort by version number
avail=$(curl -s $WINLOC | sed -n -e '/TFODBC/s/^.*href="\([^"]*\)".*/\1/p' | sort -rV)

# find latest one that is less or equal to our version
found=""
for f in $avail
do
  suff=${f#TFODBC64-}
  maj=${suff%%\.*}
  suff=${suff#*\.}
  min=${suff%%\.*}
  suff=${suff#*\.}
  pat=${suff%%\.*}
  if (( $TRAFODION_VER_MAJOR >= $maj && 
        $TRAFODION_VER_MINOR >= $min && 
        $TRAFODION_VER_UPDATE >= $pat ))
  then
    found="$f"
    break
  fi
done

if [[ -n "$found" ]]
then
  wget --no-verbose -O conn/clients/$found $WINLOC/$found
  if [[ $? != 0 ]]
  then
    echo "Error: Win-ODBC64 download failed"
  fi
else
  echo "Warning: No matching Win-ODBC64 build found"
  echo "Found only: $avail"
fi


# Use Jenkins values
VER="$(git describe --long --tags --dirty --always)"
export PV_BUILDID=${VER}_Bld${BUILD_NUMBER}
export PV_DATE=$(echo ${BUILD_TIMESTAMP} | sed 's/-//g')

make $TARGET > Make.log 2>&1
rc=$?
ls -l *.tgz 2>/dev/null

cd $WORKSPACE

exit $rc
