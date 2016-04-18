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

PATH="/bin:/usr/bin:/opt/hadoop/bin:/opt/hbase/bin:/opt/hive/bin:/opt/zookeeper/bin"
export JAVA_HOME=/usr/lib/jvm/java-1.7.0

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

# add value to file if not present
# raw - does not matter location, just tack onto end
function addraw() {
  file="$1"
  value="$2"

  grep -q "$value" $file
  if (( $? != 0 ))
  then
    echo "Adding $value to $file"
    echo "$value" >> $file
  fi
}
# add xml property value if not present
# xml - config file format
#    depends on prop/values added in single line format per this script
function addxml() {
  file="$1"
  prop="$2"
  value="$3"

  grep -q "<name>$prop</name>" $file
  if (( $? == 0 ))
  then
    grep "<name>$prop</name>" $file | grep -q "<value>$value</value>"
    if (( $? != 0 ))
    then
      echo "Updating $prop in $file"
      sed -i "/<name>$prop</s%<value>.*</value>%<value>$value</value>%" $file 
    fi
  else
    echo "Adding $prop to $file"
    sed -i "s%</configuration>%%" $file 
    echo "<property>" >> $file
    echo "  <name>$prop</name><value>$value</value>" >> $file
    echo "</property>" >> $file
    echo "</configuration>" >> $file
  fi
}

addraw /opt/hadoop/etc/hadoop/hadoop-env.sh "JAVA_HOME=$JAVA_HOME"
addraw /opt/hadoop/etc/hadoop/slaves "localhost"

addxml /opt/hadoop/etc/hadoop/core-site.xml "fs.default.name" "hdfs://localhost:50001"
addxml /opt/hadoop/etc/hadoop/core-site.xml "hadoop.tmp.dir" "/dfs/tmp"

# HDFS config for single node
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.replication" "1"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.data.dir" "/dfs/data"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.namenode.name.dir" "/dfs/name"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.http.address" "localhost:50002"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.secondary.http.address" "localhost:50003"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.address" "localhost:50004"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.http.address" "localhost:50005"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.ipc.address" "localhost:50006"

# hbase basic
addraw /opt/hbase/conf/regionservers "localhost"
addxml /opt/hbase/conf/hbase-site.xml "hbase.rootdir" "hdfs://localhost:50001/hbase"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.property.dataDir" "hdfs://localhost:50001/zoo"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.property.clientPort" "2181"
addxml /opt/hbase/conf/hbase-site.xml "hbase.master.info.port" "16010"
addxml /opt/hbase/conf/hbase-site.xml "hbase.regionserver.info.port" "16030"
addxml /opt/hbase/conf/hbase-site.xml "hbase.regionserver.port" "16088"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.quorum" "localhost"

addraw /opt/hbase/conf/hbase-env.sh "JAVA_HOME=$JAVA_HOME"
addraw /opt/hbase/conf/hbase-env.sh "HBASE_MANAGES_ZK=false"

#zoo
addraw /opt/zookeeper/conf/zoo.cfg "clientPort=2181"
addraw /opt/zookeeper/conf/zoo.cfg "autopurge.purgeInterval=24"
addraw /opt/zookeeper/conf/zoo.cfg "dataDir=/home/zookeeper"
addraw /opt/zookeeper/conf/zoo.cfg "server=localhost:2888:3888"

log_banner "Start Services and Delete HBase data"

zkServer.sh start
exit 0

# make sure we are not in HDFS safemode
mode="$(hdfs dfsadmin -safemode get 2>/dev/null)"
if [[ $mode =~ ON ]]
then
  sudo -u hdfs hdfs dfsadmin -safemode leave
fi

exit 0

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



# HDFS

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
