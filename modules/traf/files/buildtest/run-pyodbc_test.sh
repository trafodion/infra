#!/bin/bash 

source "/usr/local/bin/traf-functions.sh"
source "$HOME/.bashrc"

export TRAF_DIR="$1"                   # location of trafodion/core
export DCS_INSTALL_DIR="$2"            # location of trafodion/dcs
export TEST_DIR="$3"                   # location of pyodbc tests
export NUM_DCS=6                       # number of DCS

# check number of parameters
# if more than 4 parameters then we are also passing in tests to run
# NOTE: tests should be delimited by a space.  i.e. test_p2.ConnectTest.test11 test_p2.ConnectTest.test12
if [ $# -gt 3 ]; then
  shift
  shift
  shift
  TESTS="$*"
elif [ $# -lt 3 ]; then
  echo "ERROR: Incorrect number of input parameters."
  exit 1
fi

set -x
if [ -z "$WORKSPACE" ]; then
  export WORKSPACE=$(pwd)
fi
set +x

if [ "$TESTS" = "DONT_RUN_TESTS" ]; then
  cd "$WORKSPACE/$TEST_DIR"
  mkdir "$WORKSPACE/$TEST_DIR/logs"
  echo "INFO: Will NOT run any pyodbc tests as requested. You should not see this message in the normal Jenkins job pyodbc_test! This should only be used to turn off testing of the experimetal jobs."
  toxRes=0
  echo '<testsuite errors="0" failures="0" name="" tests="1" time="0.0">' > "$WORKSPACE/$TEST_DIR/logs/test_report.xml"
  echo '<testcase classname="NOTESTS_RAN" name="test1" time="0.0"/>' >> "$WORKSPACE/$TEST_DIR/logs/test_report.xml"
  echo '</testsuite>' >> "$WORKSPACE/$TEST_DIR/logs/test_report.xml"
else
  set -x
  # start trafodion
  cd $WORKSPACE
  /usr/local/bin/start-traf-instance.sh "$TRAF_DIR" "$DCS_INSTALL_DIR" "$NUM_DCS" || exit 1
  set +x

  echo "INFO: Waiting a minute to check for DcsServer"
  sleep 60

  set -x
  if [ $(jps | grep -c DcsServer) -ne $NUM_DCS ]; then 
    echo "ERROR: No DcsServer found. Please check your DCS setup."
    exit 1 
  fi
  echo ""

  # run pyodbc tests
  cd "$WORKSPACE/$TEST_DIR"
  mkdir "$WORKSPACE/$TEST_DIR/logs"
  export PATH=/usr/local/bin:$PATH
  ./config.sh -r -v -d localhost:37800 -t $WORKSPACE/$TRAF_DIR/conn/clients/TRAF_ODBC_Linux_Driver_64.tar.gz
  if [ $? -ne 0 ]
  then
    echo "ERROR: Could not configure Python ODBC test properly."
    exit 1
  fi
  echo ""
  set +x

  if [ -z "$TESTS" ]; then
    echo "INFO: Running ALL pyodbc tests."
    tox -e py27
    toxRes=$?
    testr last --subunit | subunit-1to2 | subunit2junitxml > "$WORKSPACE/$TEST_DIR/logs/test_report.xml"
  else 
    echo "INFO: Run only specific pyodbc tests"
    tox -e py27 -- $TESTS
    toxRes=$?
    testr last --subunit | subunit-1to2 | subunit2junitxml > "$WORKSPACE/$TEST_DIR/logs/test_report.xml"
  fi

  cd $WORKSPACE
  /usr/local/bin/stop-traf-instance.sh "$TRAF_DIR/sqf"
fi

set -x
# check to see if need to copy artifacts to logs directory
if [ $toxRes -ne 0 ]
then
  # if tox fails
  cd "$WORKSPACE/$TEST_DIR"
  cp *.ini logs
  cp env.sh logs
  cp unix_odbc.trc logs
  cp -rp .testrepository logs
fi

# exit with tox return code
exit $toxRes

