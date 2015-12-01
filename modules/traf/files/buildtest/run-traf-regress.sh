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

source "/usr/local/bin/traf-functions.sh"
log_banner

DIR="$1"  # build tree
shift
SUITES="$*"

set -x

/usr/local/bin/install-traf.sh "sqlregress" "$DIR" || exit 1

# Hive suite depends on pre-loaded TPC-DS data
if [[ "$SUITES" =~ hive|core ]]
then
    if [[ ! -f /home/jenkins/tpcds_kit.zip ]]
    then
      /usr/bin/curl --output /home/jenkins/tpcds_kit.zip http://traf-testlogs.esgyn.com/testdeps/tpcds_kit.zip
    fi
    export MY_LOCAL_SW_DIST="/home/jenkins"
    $WORKSPACE/traf_run/sql/scripts/install_hadoop_regr_test_env \
      --unpackDir=$WORKSPACE/tpcds-tool \
      --dataDir=$WORKSPACE/tpcds-data \
      --hdfsCmd="sudo -n -u hdfs /usr/bin/hdfs" \
      --hiveCmd="sudo -n -u hdfs /usr/bin/hive" \
      --logFile=$WORKSPACE/build_regr_test_env.log
        # Choose log name so it will be archived along with build logs
fi

# trafodion id created by installer
# if it exists, must run dev regressions as same user
# otherwise we are running instance locally as jenkins user
if id trafodion >/dev/null 2>&1
then
  chmod 777 $WORKSPACE # permission to write in jenkins workspace 
  sudo -n -u trafodion /usr/local/bin/run-dev-regress.sh $WORKSPACE $SUITES
  rc=$?
else
  /usr/local/bin/run-dev-regress.sh $WORKSPACE $SUITES
  rc=$?
fi

if [[ $rc != 0 ]]
then
  /usr/local/bin/save-workspace.sh $WORKSPACE
fi

/usr/local/bin/uninstall-traf.sh

exit $rc
