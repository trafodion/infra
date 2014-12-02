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

source /usr/local/bin/traf-functions.sh
log_banner
echo "*** Cleaning HBase"

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
  State="$(curl $Read $URL/clusters/trafcluster/services/trafhbase | jq -r '.serviceState')"
  if [[ $State != "STOPPED" ]]
  then
    echo "*** Stopping HBase"
    CID=$(curl $Create $URL/clusters/trafcluster/services/trafhbase/commands/stop | jq -r '.id')
    cm_cmd $CID "HBase Stop"
  fi

  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/trafhbase | jq -r '.serviceState')"
  if [[ $State != "STOPPED" ]] 
  then
    echo "Error: HBASE not stopped"
    exit 2
  fi
elif [[ $Manager == "Ambari" ]]
then
  echo "Ambari mode not yet implemented"
  /sbin/service hbase-master stop
  echo "Return code $?"
else
  /sbin/service hbase-master stop
  echo "Return code $?"
fi

####
# Make sure HDFS is running
#

if [[ $Manager == "Cloudera" ]]
then
  State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.serviceState')"

  if [[ $State == "STOPPED" ]]
  then
    # Start HDFS service roles
    CID=$(curl $Create $URL/clusters/trafcluster/services/hdfs/commands/start | jq -r '.id')
    cm_cmd $CID "HDFS Start"

    # Check status
    State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.serviceState')"
    if [[ $State =~ STOP ]] # stopped, stopping
    then
      echo "Error: HDFS not started"
      exit 2
    fi
  fi
elif [[ $Manager == "Ambari" ]]
then
  echo "Ambari mode not yet implemented"
  /sbin/service hadoop-hdfs-datanode start
  echo "Return code $?"
  /sbin/service hadoop-hdfs-namenode start
  echo "Return code $?"
else
  /sbin/service hadoop-hdfs-datanode start
  echo "Return code $?"
  /sbin/service hadoop-hdfs-namenode start
  echo "Return code $?"
fi


####
# Clear Data
#

echo "*** Clearing /hbase data from HDFS & ZooKeeper"
set -x
sudo -u hdfs /usr/bin/hadoop fs -rm -r -f -skipTrash /hbase || exit $?
sudo -u hdfs /usr/bin/hadoop fs -mkdir /hbase || exit $?
sudo -u hdfs /usr/bin/hadoop fs -chown hbase:hbase /hbase || exit $?
sudo -u zookeeper /usr/bin/hbase zkcli rmr /hbase 2>/dev/null || exit $?
sudo -u hbase rm -rf /var/log/hbase/*
set +x

####
# Remove Coprocessor config
#  Ensure we can bring up clean HBase before installing Trafodion

if [[ $Manager == "Cloudera" ]]
then
  echo "*** Removing any prior HBase coprocessor config"
  curl $Update --data '
            { "items" : [ 
                   { "name" : "hbase_master_config_safety_valve" } 
              ] }
           ' $URL/clusters/trafcluster/services/trafhbase/roles/trafMAS/config | jq -r '.message'
  curl $Update --data '
            { "items" : [ 
                   { "name" : "hbase_coprocessor_region_classes" }, 
                   { "name" : "hbase_regionserver_config_safety_valve" }
              ] } 
           ' $URL/clusters/trafcluster/services/trafhbase/roles/trafREG/config | jq -r '.message'
elif [[ $Manager == "Ambari" ]]
then
  echo "Ambari mode not yet implemented"
## nothing to do for manual - install case
fi


####
# Clear cache and re-set hbase data
#
if [[ $Manager == "Cloudera" ]]
then
  echo "*** Re-starting cluster"
  CID=$(curl $Create $URL/clusters/trafcluster/commands/stop | jq -r '.id')
  cm_cmd $CID "Cluster stop"
  CID=$(curl $Create $URL/clusters/trafcluster/commands/start | jq -r '.id')
  cm_cmd $CID "Cluster start"

  State="$(curl $Read $URL/clusters/trafcluster/services/trafhbase | jq -r '.serviceState')"
  if [[ $State =~ STOP ]] # stopped, stopping
  then
     echo "Error: HBase not started"
     exit 2
  fi
elif [[ $Manager == "Ambari" ]]
then
  echo "Ambari mode not yet implemented"
## nothing to do for manual - install case (leave hbase down)
fi

exit 0
