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
log_banner

export TRAF_DIR="$1"                   # location of trafodion/core
export DCS_INSTALL_DIR="$2"            # location of trafodion/dcs
export JAVA_HOME="$3"                  # Java SDK Home Directory
export TEST_DIR="$4"                   # location of trafodion/dcs/src/test/jdbc_test
export PATH=$JAVA_HOME/bin:$PATH       # add $JAVA_HOME/bin to the path
export TESTS=""                        # initialize TESTS to empty string

# check number of parameters
# if more than 4 parameters then we are also passing in tests to run
# NOTE: tests need to start with "--tests=" and should be delimited by a comma with no space.  
# i.e. --tests=TestBasic,SomeOtherTestName
if [ $# -gt 4 ]; then
  shift
  shift
  shift
  shift
  TESTS="$*"

  # exit if no tests need to be run
  if [[ "$TESTS" == "DONT_RUN_TESTS" ]]; then
    echo "INFO: Will NOT run any JDBC tests as requested. You should not see this message in the normal Jenkins job jdbc_test! This should only be used to turn off testing of the experimetal jobs."
    exit 0
  # exit if tests option not specified correctly
  elif [[ ! -z "$TESTS" ]] && ! [[ $TESTS =~ ^--tests=.* ]]; then
    echo "ERROR: Incorrect specification for the tests option. The tests option should start with --tests= and should be delimited by a comma with no space."
    echo "       i.e.  --tests=TestBasic,SomeOtherTestName"
    exit 1
  fi
elif [ $# -lt 4 ]; then
  echo "ERROR: Incorrect number of input parameters."
  exit 1
fi

set -x

# start trafodion
cd $WORKSPACE
/usr/local/bin/install-traf.sh "$TRAF_DIR" "$DCS_INSTALL_DIR" "6" || exit 1
set +x

echo "INFO: Waiting 2 minutes and check DcsServer"
sleep 120

set -x
if [ $(jps | grep -c DcsServer) -ne 6 ]; then
  echo "ERROR: No DcsServer found. Please check your DCS setup."
  exit 1
fi
echo ""

# run jdbc_test
log_banner "jdbc_test.py"
cd "$WORKSPACE/$TEST_DIR"
./jdbc_test.py --appid=jdbc_test --target=localhost:37800 \
     --user=dontcare --pw=dontcare --javahome=$JAVA_HOME \
     --jdbctype=T4 --jdbccp=$WORKSPACE/$TRAF_DIR/sqf/export/lib/jdbcT4.jar ${TESTS}
jdbcRes=$?

cd $WORKSPACE
/usr/local/bin/uninstall-traf.sh "$TRAF_DIR/sqf"

# exit with jdbc_test.py return code
exit $jdbcRes

