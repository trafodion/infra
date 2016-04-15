#!/bin/bash
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

# Simple single-node cluster for test environment

PATH="/bin:/usr/bin"

log_banner "Checking Cluster Configuration"
echo "*** Checking Cluster Configuration"

# Distro


# previously saved?
if [[ -r /var/local/TrafTestDistro ]]
then
  Vers="$(</var/local/TrafTestDistro)"
  echo "Retriving distro from /var/local/TrafTestDistro: $Vers"
else
  Vers="$1"
  if [[ ! $Vers =~ ^[0-9][.0-9]+$ ]]
  then
    echo "Error: Distro not specified in /var/local/TrafTestDistro nor on command line"
    echo "Error: Usage: $0 <HBase-version-number>"
    exit 1
  fi
  echo "$Vers" > /var/local/TrafTestDistro
fi


# HDFS config for single node
cm_config_serv "hdfs" "dfs_replication" "1"

# Hive config
cm_config_serv "trafHIVE" "mapreduce_yarn_service" "trafMAPRED"
cm_config_serv "trafHIVE" "zookeeper_service" "zookeeper"
cm_config_serv "trafHIVE" "hive_metastore_database_password" "insecure_hive"

# MapReduce config
cm_config_serv "trafMAPRED" "hdfs_service" "hdfs"

# HBase config
cm_config_serv "trafhbase" "hdfs_service" "hdfs"
cm_config_serv "trafhbase" "zookeeper_service" "zookeeper"


# Set Java Heap Size for all server roles
# much smaller than defaults due to small mem size of test environment
HEAP=536870912  # half GB
RSHEAP=$(( HEAP * 2 ))
cm_config_serv "hdfs/roles/trafDATA" "datanode_java_heapsize" "$HEAP"
cm_config_serv "hdfs/roles/trafNAME" "namenode_java_heapsize" "$HEAP"
cm_config_serv "hdfs/roles/trafSEC"  "secondary_namenode_java_heapsize" "$HEAP"
cm_config_serv "zookeeper/roles/trafSERV" "zookeeper_server_java_heapsize" "$HEAP"
cm_config_serv "trafMAPRED/roles/trafJOB" "jobtracker_java_heapsize" "$HEAP"
cm_config_serv "trafHIVE/roles/trafMETA" "hive_metastore_java_heapsize" "$HEAP"
cm_config_serv "trafHIVE/roles/trafHSRV" "hiveserver2_java_heapsize" "$HEAP"
cm_config_serv "trafhbase/roles/trafMAS" "hbase_master_java_heapsize" "$HEAP"
cm_config_serv "trafhbase/roles/trafREG" "hbase_regionserver_java_heapsize" "$RSHEAP"


log_banner "Start Services and Delete HBase data"


# HDFS

  # make sure we are not in HDFS safemode
  mode="$(hdfs dfsadmin -safemode get)"
  if [[ $mode =~ ON ]]
  then
    sudo -u hdfs hdfs dfsadmin -safemode leave
  fi
  # Make sure namenode is formatted

  start_service hdfs

  # wait for safemode so we can modify hdfs data
  sudo -u hdfs hdfs dfsadmin -safemode wait

### Standard directories that need only to be created once

# Hive set-up
hdfs dfs -ls /user/hive >/dev/null

hdfs dfs -ls /user/hive/warehouse >/dev/null

# MapReduce needs /tmp
hdfs dfs -ls /tmp >/dev/null

### HBase data should be cleaned up every time
echo "*** Removing HBase Data"

# requires zookeeper up
start_service zookeeper

# hbase must be down

# data locations for Cloudera
hdata="/hbase"  # HDFS
zkdata="/hbase" # zookeeper

sudo -u hdfs /usr/bin/hdfs dfs -rm -r -f -skipTrash $hdata || exit $?
sudo -u zookeeper /usr/bin/hbase zkcli rmr $zkdata 2>/dev/null || exit $?

# clean up logs so we can save only what is logged for this run
sudo -u hbase rm -rf /var/log/hbase/*

# recreate root

# verify nothing is using HBase port
  HPort='60010'
  # ss will let us know if port is in use, and -p option will give us process info
  cmd="/usr/sbin/ss -lp src *:$HPort"

  pcount=$($cmd | wc -l)
  pids=$(sudo -n $cmd | sed -n '/users:/s/^.*users:((.*,\([0-9]*\),.*$/\1/p')
  if [[ $pcount > 1 ]] # always get header line
  then
    echo "Warning: found port $HPort in use"
    $cmd
  fi
  if [[ -n $pids ]]
  then
    echo "Warning: processes using port $HPort"
    ps -f $pids
    echo "Warning: killing pids: $pids"
    kill $pids
  fi

start_service trafHIVE
start_service trafMAPRED
start_service trafhbase

echo "*** Cluster Check Complete"

exit 0
