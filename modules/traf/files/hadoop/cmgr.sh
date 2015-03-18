#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2010-2014 Hewlett-Packard Development Company, L.P.
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

# Interact with Cloudera Manager for initial cluster set-up
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
    echo "Error: Usage: $0 <CDH-full-version-number>"
    exit 1
  fi
  echo "$Vers" > /var/local/TrafTestDistro
fi


# curl options
URL="http://localhost:7180/api/v7"
# silent (no progress msgs), default user/pw 
Opts="-su admin:admin"

Read="$Opts"
Create="-X POST -H Content-Type:application/json $Opts"
Update="-X PUT -H Content-Type:application/json $Opts"

# Function - poll command until it completes and report results
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
# Function - configure service 
function cm_config_serv {
  service=$1
  param=$2
  value="$3"

  Config="$(curl $Read $URL/clusters/trafcluster/services/${service}/config | jq -r '.items[].name')"

  if [[ ! $Config =~ $param ]]
  then
    echo "Updating $service $param config"
    Config=$(curl $Update -d'
		  { "items" : [ {
		      "name" : "'$param'",
		      "value" : "'$value'"
		    } ] }
		  ' $URL/clusters/trafcluster/services/${service}/config | jq -r '.items[].name'
       )
    if [[ ! ($Config =~ $param) ]]
    then
      echo "Error: failed to update $service config"
      exit 2
    fi
fi
}

# Check that we can talk to CM
curl $Read $URL/tools/echoError?message="hello" | grep -q hello
if [[ $? != 0 ]]
then
  echo "Error: cannot contact cloudera manager"
  exit 2
fi

# Create Cluster 
Cluster="$(curl $Read $URL/clusters/trafcluster | jq -r '.name')"

if [[ $Cluster == "null" ]]
then
  echo "Creating cluster: trafcluster"
  Cluster=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafcluster",
		      "fullVersion" : "'$Vers'"
		    } ] }
		  ' $URL/clusters |
		  jq -r '.items[0].name'
       )
  if [[ $Cluster != "trafcluster" ]]
  then
    echo "Error: failed to create cluster"
    exit 2
  fi
fi

# Create Services 
# installer cannot understand arbitrary names for hdfs and hbase services Bug:1381764
# specify type:name
for serv in HDFS:hdfs HIVE:trafHIVE HBASE:trafhbase ZOOKEEPER:trafZOO MAPREDUCE:trafMAPRED YARN:trafYARN
do
  stype=${serv%:*}
  sname=${serv#*:}
  Service="$(curl $Read $URL/clusters/trafcluster/services/$sname | jq -r '.name')"

  if [[ $Service == "null" ]]
  then
    echo "Creating service: $sname"
    Service=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "'$sname'",
		      "type" : "'$stype'"
		    } ] }
		  ' $URL/clusters/trafcluster/services |
		  jq -r '.items[0].name'
       )
    if [[ $Service != "$sname" ]]
    then
      echo "Error: failed to create $sname service"
      exit 2
    fi
  fi
done

# HDFS config for single node
cm_config_serv "hdfs" "dfs_replication" "1"

# Hive config
cm_config_serv "trafHIVE" "mapreduce_yarn_service" "trafMAPRED"
cm_config_serv "trafHIVE" "zookeeper_service" "trafZOO"
cm_config_serv "trafHIVE" "hive_metastore_database_password" "insecure_hive"

# MapReduce config
cm_config_serv "trafMAPRED" "hdfs_service" "hdfs"

# Yarn config
cm_config_serv "trafYARN" "hdfs_service" "hdfs"
cm_config_serv "trafYARN" "zookeeper_service" "trafZOO"

# HBase config
cm_config_serv "trafhbase" "hdfs_service" "hdfs"
cm_config_serv "trafhbase" "zookeeper_service" "trafZOO"

# Create Service Roles -- all on local host
host=$(hostname -f)

# HDFS
Role="$(curl $Read $URL/clusters/trafcluster/services/hdfs/roles/trafSEC | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating HDFS roles"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafDATA",
		      "type" : "DATANODE",
		      "hostRef" : { "hostId" : "'$host'" },
		      "config" : { "items" : [ {
		                      "name" : "dfs_data_dir_list",
				      "value" : "/data/dfs/data"
		                 } ] }
		    }, {
		      "name" : "trafNAME",
		      "type" : "NAMENODE",
		      "hostRef" : { "hostId" : "'$host'" },
		      "config" : { "items" : [ {
		                      "name" : "dfs_name_dir_list",
				      "value" : "/data/dfs/name"
		                 } ] }
		    }, {
		      "name" : "trafSEC",
		      "type" : "SECONDARYNAMENODE",
		      "hostRef" : { "hostId" : "'$host'" },
		      "config" : { "items" : [ {
		                      "name" : "fs_checkpoint_dir_list",
				      "value" : "/data/dfs/secname"
		                 } ] }
		    } ] }
		  ' $URL/clusters/trafcluster/services/hdfs/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafDATA && $Roles =~ trafNAME) ]]
  then
    echo "Error: failed to create HDFS roles"
    exit 2
  fi
fi

# Zookeeper
Role="$(curl $Read $URL/clusters/trafcluster/services/trafZOO/roles/trafSERV | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating Zookeeper role"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafSERV",
		      "type" : "SERVER",
		      "hostRef" : { "hostId" : "'$host'" }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafZOO/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafSERV) ]]
  then
    echo "Error: failed to create Zookeeper roles"
    exit 2
  fi
fi

# MapReduce
Role="$(curl $Read $URL/clusters/trafcluster/services/trafMAPRED/roles/trafJOB | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating MapReduce role"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafJOB",
		      "type" : "JOBTRACKER",
		      "hostRef" : { "hostId" : "'$host'" },
		      "config" : { "items" : [ {
		                      "name" : "jobtracker_mapred_local_dir_list",
				      "value" : "/data/mr/jobs"
		                 } ] }
		    }, {
		      "name" : "trafTASK",
		      "type" : "TASKTRACKER",
		      "hostRef" : { "hostId" : "'$host'" },
		      "config" : { "items" : [ {
		                      "name" : "tasktracker_mapred_local_dir_list",
				      "value" : "/data/mr/tasks"
		                 } ] }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafMAPRED/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafJOB) ]]
  then
    echo "Error: failed to create MapReduce roles"
    exit 2
  fi
fi

# Yarn
Role="$(curl $Read $URL/clusters/trafcluster/services/trafYARN/roles/trafRESMGR | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating Yarn roles"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafNODEMGR",
		      "type" : "NODEMANAGER",
		      "hostRef" : { "hostId" : "'$host'" }
		    }, {
		      "name" : "trafJHIST",
		      "type" : "JOBHISTORY",
		      "hostRef" : { "hostId" : "'$host'" }
		    }, {
		      "name" : "trafRESMGR",
		      "type" : "RESOURCEMANAGER",
		      "hostRef" : { "hostId" : "'$host'" }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafYARN/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafNODEMGR) ]]
  then
    echo "Error: failed to create Yarn roles"
    exit 2
  fi
fi

# Configure Yarn roles
cm_config_serv "trafYARN/roles/trafNODEMGR" "yarn_nodemanager_local_dirs" '/var/lib/hadoop-yarn/cache/nm-local-dir'

# Hive
Role="$(curl $Read $URL/clusters/trafcluster/services/trafHIVE/roles/trafMETA | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating Hive role"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafMETA",
		      "type" : "HIVEMETASTORE",
		      "hostRef" : { "hostId" : "'$host'" }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafHIVE/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafMETA) ]]
  then
    echo "Error: failed to create Hive roles"
    exit 2
  fi
fi

Role="$(curl $Read $URL/clusters/trafcluster/services/trafHIVE/roles/trafHSRV | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating Hive role"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafHSRV",
		      "type" : "HIVESERVER2",
		      "hostRef" : { "hostId" : "'$host'" }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafHIVE/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafHSRV) ]]
  then
    echo "Error: failed to create Hive roles"
    exit 2
  fi
fi

# HBase
Role="$(curl $Read $URL/clusters/trafcluster/services/trafhbase/roles/trafMAS | jq -r '.name')"

if [[ $Role == "null" ]]
then
  echo "Creating HBase roles"
  Roles=$(curl $Create -d'
		  { "items" : [ {
		      "name" : "trafMAS",
		      "type" : "MASTER",
		      "hostRef" : { "hostId" : "'$host'" }
		    }, {
		      "name" : "trafREG",
		      "type" : "REGIONSERVER",
		      "hostRef" : { "hostId" : "'$host'" }
		    } ] }
		  ' $URL/clusters/trafcluster/services/trafhbase/roles | jq -r '.items[].name'
       )
  if [[ ! ($Roles =~ trafMAS && $Roles =~ trafREG) ]]
  then
    echo "Error: failed to create HBase roles"
    exit 2
  fi
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
fi

# Deploy Client Config
State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.clientConfigStalenessStatus')"
if [[ $State =~ STALE ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/commands/deployClientConfig | jq -r '.id')
  cm_cmd $CID "Client Deploy"
fi


log_banner "Start Services and Delete HBase data"

function start_service() {
  serv=$1
  State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
  if [[ $State == "STOPPED" ]]
  then
    echo "*** Starting $serv"
    CID=$(curl $Create $URL/clusters/trafcluster/services/${serv}/commands/start | jq -r '.id')
    cm_cmd $CID "$serv Start"
    # Check status
    State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
    if [[ $State =~ STOP ]] # stopped, stopping
    then
      echo "Error: $serv not started"
      exit 2
    fi
  fi
}

# HDFS

State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.serviceState')"

if [[ $State != "STOPPED" ]]
then
  # make sure we are not in HDFS safemode
  mode="$(hdfs dfsadmin -safemode get)"
  if [[ $mode =~ ON ]]
  then
    sudo -u hdfs hdfs dfsadmin -safemode leave
  fi
elif [[ $State == "STOPPED" ]]
then
  # Make sure namenode is formatted
  CID=$(curl $Create -d'
		  { "items" : [ "trafNAME" ] }
  		' $URL/clusters/trafcluster/services/hdfs/roleCommands/hdfsFormat |
		  jq -r '.items[0].id'
	)
  cm_cmd $CID "HDFS Format"

  start_service hdfs

  # wait for safemode so we can modify hdfs data
  sudo -u hdfs hdfs dfsadmin -safemode wait
fi

### Standard directories that need only to be created once

# Hive set-up
hdfs dfs -ls /user/hive >/dev/null
if [[ $? != 0 ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafHIVE/commands/hiveCreateHiveUserDir | jq -r '.id')
  cm_cmd $CID "Hive Create User Dir"
  hdfs dfs -ls /user/hive >/dev/null || exit 2
fi

hdfs dfs -ls /user/hive/warehouse >/dev/null
if [[ $? != 0 ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafHIVE/commands/hiveCreateHiveWarehouse | jq -r '.id')
  cm_cmd $CID "Hive Create Warehouse"
  hdfs dfs -ls /user/hive/warehouse >/dev/null || exit 2
fi

# MapReduce needs /tmp
hdfs dfs -ls /tmp >/dev/null
if [[ $? != 0 ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/services/hdfs/commands/hdfsCreateTmpDir | jq -r '.id')
  cm_cmd $CID "HDFS Create tmp"
  hdfs dfs -ls /tmp >/dev/null || exit 2
fi

# Yarn needs app log dir
hdfs dfs -ls /tmp/logs >/dev/null
if [[ $? != 0 ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafYARN/commands/yarnNodeManagerRemoteAppLogDirCommand | jq -r '.id')
  cm_cmd $CID "HDFS Create app logs dir"
  hdfs dfs -ls /tmp/logs >/dev/null || exit 2
fi

# Yarn/MR job history 
hdfs dfs -ls /user/history >/dev/null
if [[ $? != 0 ]]
then
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafYARN/commands/yarnCreateJobHistoryDirCommand | jq -r '.id')
  cm_cmd $CID "HDFS Create job history dir"
  hdfs dfs -ls /user/history >/dev/null || exit 2
fi

### HBase data should be cleaned up every time
echo "*** Removing HBase Data"

# requires zookeeper up
start_service trafZOO

# hbase must be down
State="$(curl $Read $URL/clusters/trafcluster/services/trafhbase | jq -r '.serviceState')"
if [[ $State != "STOPPED" ]]
then
  echo "*** Stopping HBase"
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafhbase/commands/stop | jq -r '.id')
  cm_cmd $CID "HBase Stop"
fi

# data locations for Cloudera
hdata="/hbase"  # HDFS
zkdata="/hbase" # zookeeper

sudo -u hdfs /usr/bin/hdfs dfs -rm -r -f -skipTrash $hdata || exit $?
sudo -u zookeeper /usr/bin/hbase zkcli rmr $zkdata 2>/dev/null || exit $?

# clean up logs so we can save only what is logged for this run
sudo -u hbase rm -rf /var/log/hbase/*

# recreate root
CID=$(curl $Create $URL/clusters/trafcluster/services/trafhbase/commands/hbaseCreateRoot | jq -r '.id')
cm_cmd $CID "HBase Create root"

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
start_service trafYARN
start_service trafMAPRED
start_service trafhbase

echo "*** Cluster Check Complete"

exit 0
