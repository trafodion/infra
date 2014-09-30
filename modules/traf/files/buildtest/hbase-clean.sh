#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2013-2014 Hewlett-Packard Development Company, L.P.
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

# Clean up all HBase data to start fresh test run

if rpm -q cloudera-manager-server >/dev/null
then
  Manager="Cloudera"
  URL="http://localhost:7180/api/v7"
  Opts="-su admin:admin"
  Read="$Opts"
  Create="-X POST -H Content-Type:application/json $Opts"
  Update="-X PUT -H Content-Type:application/json $Opts"
elif rpm -q ambari-server >/dev/null
then
  Manager="Ambari"
else
  Manager="None"
fi


# cloudera command - poll command until it completes and report results
function cm_cmd {
  id=$1
  action="$2"
  if [[ $id =~ [0-9]+ ]]
  then
    running=''
    until [[ $running == "false" ]]
    do
      sleep 2
      running=$(curl $Read $URL/commands/$id | jq -r '.active')
    done
    result=$(curl $Read $URL/commands/$id | jq -r '.resultMessage')
    echo "$action result: $result"
  else
    echo "$action command did not launch"
  fi
}

####
# Stop HBase
#

if [[ $Manager == "Cloudera" ]]
then
  State="$(curl $Read $URL/clusters/trafcluster/services/trafHBASE | jq -r '.serviceState')"
  if [[ $State != "STOPPED" ]]
  then
    CID=$(curl $Create $URL/clusters/trafcluster/services/trafHBASE/commands/stop | jq -r '.id')
    cm_cmd $CID "HBase Stop"
  fi

  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/trafHBASE | jq -r '.serviceState')"
  if [[ $State != "STOPPED" ]] 
  then
    echo "Error: HBASE not stopped"
    exit 2
  fi
elif [[ $Manager == "Ambari" ]]
then
  echo "Ambari mode not yet implemented"
  exit 1
else
  /sbin/service hbase-master stop
  echo "Return code $?"
fi


####
# Clear Data
#

echo "Removing/Creating HDFS /hbase"
set -x
sudo -u hdfs /usr/bin/hadoop fs -rm -r -f /hbase || exit $?
sudo -u hdfs /usr/bin/hadoop fs -mkdir /hbase || exit $?
sudo -u hdfs /usr/bin/hadoop fs -chown hbase:hbase /hbase || exit $?
set +x

exit 0
