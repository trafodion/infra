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

  grep -q "$value" $file 2>/dev/null
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

addraw /opt/hadoop/etc/hadoop/hadoop-env.sh "export JAVA_HOME=$JAVA_HOME"
addraw /opt/hadoop/etc/hadoop/slaves "localhost"

addxml /opt/hadoop/etc/hadoop/core-site.xml "fs.default.name" "hdfs://localhost:50001"
addxml /opt/hadoop/etc/hadoop/core-site.xml "hadoop.tmp.dir" "/dfs/tmp"

# HDFS config for single node
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.replication" "1"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.data.dir" "/dfs/data"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.namenode.name.dir" "/dfs/name"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.namenode.acls.enabled" "true"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.http.address" "localhost:50002"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.secondary.http.address" "localhost:50003"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.address" "localhost:50004"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.http.address" "localhost:50005"
addxml /opt/hadoop/etc/hadoop/hdfs-site.xml "dfs.datanode.ipc.address" "localhost:50006"

# hbase basic
addraw /opt/hbase/conf/regionservers "localhost"
addxml /opt/hbase/conf/hbase-site.xml "hbase.rootdir" "hdfs://localhost:50001/hbase"
addxml /opt/hbase/conf/hbase-site.xml "hbase.cluster.distributed" "true"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.property.dataDir" "hdfs://localhost:50001/zoo"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.property.clientPort" "2181"
addxml /opt/hbase/conf/hbase-site.xml "hbase.master.info.port" "16010"
addxml /opt/hbase/conf/hbase-site.xml "hbase.regionserver.info.port" "16030"
addxml /opt/hbase/conf/hbase-site.xml "hbase.regionserver.port" "16088"
addxml /opt/hbase/conf/hbase-site.xml "hbase.zookeeper.quorum" "localhost"

addraw /opt/hbase/conf/hbase-env.sh "export JAVA_HOME=$JAVA_HOME"
addraw /opt/hbase/conf/hbase-env.sh "export HBASE_MANAGES_ZK=false"

#zoo
addraw /opt/zookeeper/conf/zoo.cfg "clientPort=2181"
addraw /opt/zookeeper/conf/zoo.cfg "autopurge.purgeInterval=24"
addraw /opt/zookeeper/conf/zoo.cfg "dataDir=/home/tinstall/zookeeper"
addraw /opt/zookeeper/conf/zoo.cfg "server=localhost:2888:3888"
addraw /opt/zookeeper/conf/zookeeper-env.sh "export JAVA_HOME=$JAVA_HOME"

# hive
if [[ ! -f /opt/hive/conf/hive-site.xml ]]
then
  echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' > /opt/hive/conf/hive-site.xml
  echo '<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>' >> /opt/hive/conf/hive-site.xml
  echo '<configuration>' >> /opt/hive/conf/hive-site.xml
  echo '</configuration>' >> /opt/hive/conf/hive-site.xml
fi
addxml /opt/hive/conf/hive-site.xml "javax.jdo.option.ConnectionURL" "jdbc:mysql://localhost/metastore"
addxml /opt/hive/conf/hive-site.xml "javax.jdo.option.ConnectionDrivername" "com.mysql.jdbc.Driver"
addxml /opt/hive/conf/hive-site.xml "javax.jdo.option.ConnectionUserName" "hive"
addxml /opt/hive/conf/hive-site.xml "javax.jdo.option.ConnectionPassword" "insecure_hive"

addraw /opt/hive/conf/hive-env.sh "export JAVA_HOME=$JAVA_HOME"
addraw /opt/hive/conf/hive-env.sh "export HADOOP_HOME=/opt/hadoop"
addraw /opt/hive/conf/hive-env.sh "export HADOOP_USER_CLASSPATH_FIRST=true"

log_banner "Start Services and Delete HBase data"


cd /tmp # write-output file here
sudo -u tinstall /opt/zookeeper/bin/zkServer.sh status || \
    sudo -u tinstall /opt/zookeeper/bin/zkServer.sh start

# make sure we are not in HDFS safemode
mode="$(hdfs dfsadmin -safemode get 2>/dev/null)"
if [[ $mode =~ ON ]]
then
  sudo -u tinstall /opt/hadoop/bin/hdfs dfsadmin -safemode leave
fi

# first time - format namenode
if [[ ! -d /dfs/name ]]
then
  echo "Formatting Name-Node"
  sudo -u tinstall /opt/hadoop/bin/hdfs namenode -format -force
fi

echo "Starting DFS"
sudo -u tinstall /opt/hadoop/sbin/start-dfs.sh

# wait for safemode so we can modify hdfs data
sudo -u tinstall /opt/hadoop/bin/hdfs dfsadmin -safemode wait

### Standard directories that need only to be created once

echo "Creating HDFS directories"
# Hive set-up
sudo -u tinstall /opt/hadoop/bin/hdfs dfs -mkdir -p /user/hive >/dev/null

sudo -u tinstall /opt/hadoop/bin/hdfs dfs -mkdir -p /user/hive/warehouse >/dev/null

# MapReduce needs /tmp
sudo -u tinstall /opt/hadoop/bin/hdfs dfs -mkdir -p /tmp >/dev/null

### HBase data should be cleaned up every time

# hbase must be down
echo "Stopping HBase"
sudo -u tinstall /opt/hbase/bin/stop-hbase.sh
sudo -u tinstall  /opt/hbase/bin/hbase-daemon.sh stop regionserver

for i in 2 5 10 20
do
  sudo -u tinstall jps | grep -q -e HMaster -e HRegionServer
  if [[ $? == 0 ]]
  then
    sudo pkill -u tinstall -f HRegionServer
    sudo pkill -u tinstall -f HMaster
    sleep $i
  else
    break
  fi
done
sudo -u tinstall jps

echo "Removing HBase Data"
# data locations
hdata="/hbase"  # HDFS
zkdata="/hbase" # zookeeper

sudo -u tinstall /opt/hadoop/bin/hdfs dfs -rm -r -f -skipTrash $hdata || exit $?
sudo -u tinstall /opt/hbase/bin/hbase zkcli rmr $zkdata 2>/dev/null || exit $?

# clean up logs so we can save only what is logged for this run
sudo -u tinstall rm -rf /var/log/hbase/*

# recreate root
sudo -u tinstall /opt/hadoop/bin/hdfs dfs -mkdir -p $hdata >/dev/null

# start HBase
echo "Starting HBase"
sudo -u tinstall /opt/hbase/bin/start-hbase.sh

# start hive
if [[ -z $(pgrep -u tinstall -f HiveServer) ]]
then
  echo "Starting Hive"
  sudo -u tinstall /opt/hive/bin/hiveserver2 &
fi
sudo -u tinstall jps


# Prepare for TRX installation
addxml /opt/hbase/conf/hbase-site.xml "hbase.coprocessor.region.classes" "org.apache.hadoop.hbase.coprocessor.transactional.TrxRegionObserver,org.apache.hadoop.hbase.coprocessor.transactional.TrxRegionEndpoint,org.apache.hadoop.hbase.coprocessor.AggregateImplementation"
addxml /opt/hbase/conf/hbase-site.xml "hbase.hregion.impl" "org.apache.hadoop.hbase.regionserver.transactional.TransactionalRegion"

echo "*** Cluster Check Complete"

exit 0
