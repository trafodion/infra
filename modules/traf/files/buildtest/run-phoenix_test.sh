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

source "/usr/local/bin/traf-functions.sh"

export TRAF_DIR="$1"                   # location of trafodion/core
export DCS_INSTALL_DIR="$2"            # location of trafodion/dcs
export JAVA_HOME="$3"                  # Java SDK Home Directory
export TEST_DIR="$4"                   # location of trafodion/phoenix_test
export PATH=$JAVA_HOME/bin:$PATH       # add $JAVA_HOME/bin to the path

# check number of parameters
# if more than 4 parameters then we are also passing in tests to run
# NOTE: tests should be delimited by a comma with no space.  i.e. AlterTableTest,ArithmeticQueryTest
if [ $# -gt 4 ]; then
  shift
  shift
  shift
  shift
  TESTS="$*"
elif [ $# -lt 4 ]; then
  echo "ERROR: Incorrect number of input parameters."
  exit 1
fi

set -x
if [ -z "$WORKSPACE" ]; then
  export WORKSPACE=$(pwd)
fi

# start trafodion
cd $WORKSPACE
ulimit -c unlimited
/usr/local/bin/start-traf-instance.sh "$TRAF_DIR" "$DCS_INSTALL_DIR" "6" || exit 1
set +x

echo "INFO: Waiting 2 minutes and check DcsServer"
sleep 120

set -x
if [ $(jps | grep -c DcsServer) -ne 6 ]; then
  echo "ERROR: No DcsServer found. Please check your DCS setup."
  exit 1
fi
echo ""

# run phoenix_test
cd "$WORKSPACE/$TEST_DIR"
if [ -z "$TESTS" ]; then
  ./phoenix_test.py --target=localhost:37800 --user=dontcare --pw=dontcare --targettype=TR --javahome=$JAVA_HOME --jdbccp=$WORKSPACE/$TRAF_DIR/sqf/export/lib/jdbcT4.jar
  phoenixRes=$?
elif [ "$TESTS" = "DONT_RUN_TESTS" ]; then
  echo "INFO: Will NOT run any phoenix tests as requested. You should not see this message in the normal Jenkins job phoenix_test! This should only be used to turn off testing of the experimetal jobs."
  phoenixRes=0
else
  ./phoenix_test.py --target=localhost:37800 --user=dontcare --pw=dontcare --targettype=TR --javahome=$JAVA_HOME --jdbccp=$WORKSPACE/$TRAF_DIR/sqf/export/lib/jdbcT4.jar --tests=$TESTS
  phoenixRes=$?
fi

cd $WORKSPACE
/usr/local/bin/stop-traf-instance.sh "$TRAF_DIR/sqf"

# Any core files means failure
report_on_corefiles "$TRAF_DIR"
coreCount=$?
if [[ $coreCount -gt 0 ]]; then
  echo
  echo "ERROR : Found $coreCount core files"
  echo
fi

phoenixRes=$(( phoenixRes + coreCount ))

# exit with sum of return codes from phoenix_test.py and report_on_corefiles
exit $phoenixRes
