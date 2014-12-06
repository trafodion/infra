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

# Interact with Cloudera Manager for initial cluster set-up
# Simple single-node cluster for test environment

PATH="/bin:/usr/bin"

# check mode is read-only
# check if set-up is correct, exit as soon as problem is found
if [[ $1 == "check" ]]
then
  mode="check"
  shift
else
  mode=""
fi

Vers="$1"
if [[ ! $Vers =~ ^[0-9][.0-9]+$ ]]
then
  echo "Error: Usage: $0 [check] <CDH-full-version-number>"
  exit 1
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
    [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
    [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
  [[ $mode == "check" ]] && exit 5
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
fi

########## End of Configurations

# Check whether previously initialized
if [[ -f /var/local/Cluster_Init_Trafodion ]]
then
  echo "File /var/local/Cluster_Init_Trafodion exists."
  echo "Skipping initialization steps."
  exit 0
fi

########## Start of Initialization

# Start HDFS

State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.serviceState')"

if [[ $State == "STOPPED" ]]
then
  # Make sure namenode is formatted
  CID=$(curl $Create -d'
		  { "items" : [ "trafNAME" ] }
  		' $URL/clusters/trafcluster/services/hdfs/roleCommands/hdfsFormat |
		  jq -r '.items[0].id'
	)
  cm_cmd $CID "HDFS Format"

  [[ $mode == "check" ]] && exit 5
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

# Deploy Client Config
State="$(curl $Read $URL/clusters/trafcluster/services/hdfs | jq -r '.clientConfigStalenessStatus')"
if [[ $State =~ STALE ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/commands/deployClientConfig | jq -r '.id')
  cm_cmd $CID "Client Deploy"
fi

# Hive set-up
hadoop fs -ls /user/hive >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafHIVE/commands/hiveCreateHiveUserDir | jq -r '.id')
  cm_cmd $CID "Hive Create User Dir"
fi
hadoop fs -ls /user/hive >/dev/null || exit 2

hadoop fs -ls /user/hive/warehouse >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafHIVE/commands/hiveCreateHiveWarehouse | jq -r '.id')
  cm_cmd $CID "Hive Create Warehouse"
fi
hadoop fs -ls /user/hive/warehouse >/dev/null || exit 2

# MapReduce needs /tmp
hadoop fs -ls /tmp >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/hdfs/commands/hdfsCreateTmpDir | jq -r '.id')
  cm_cmd $CID "HDFS Create tmp"
fi
hadoop fs -ls /tmp >/dev/null || exit 2

# Yarn needs app log dir
hadoop fs -ls /tmp/logs >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafYARN/commands/yarnNodeManagerRemoteAppLogDirCommand | jq -r '.id')
  cm_cmd $CID "HDFS Create app logs dir"
fi
hadoop fs -ls /tmp/logs >/dev/null || exit 2

# Yarn/MR job history 
hadoop fs -ls /user/history >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafYARN/commands/yarnCreateJobHistoryDirCommand | jq -r '.id')
  cm_cmd $CID "HDFS Create job history dir"
fi
hadoop fs -ls /user/history >/dev/null || exit 2


# HBase root 
hadoop fs -ls /hbase >/dev/null
if [[ $? != 0 ]]
then
  [[ $mode == "check" ]] && exit 5
  CID=$(curl $Create $URL/clusters/trafcluster/services/trafhbase/commands/hbaseCreateRoot | jq -r '.id')
  cm_cmd $CID "HBase Create root"
fi
hadoop fs -ls /hbase >/dev/null || exit 2


# Start services
for serv in trafZOO trafHIVE trafYARN trafMAPRED trafhbase
do
  State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
  if [[ $State == "STOPPED" ]]
  then
    [[ $mode == "check" ]] && exit 5
    CID=$(curl $Create $URL/clusters/trafcluster/services/${serv}/commands/start | jq -r '.id')
    cm_cmd $CID "$serv Start"
  fi
  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
  if [[ $State =~ STOP ]] # stopped, stopping
  then
    echo "Error: $serv not started"
    exit 2
  fi
done

# Successfully initialized - don't repeat initialization
echo "Cluster set-up complete $(date)" > /var/local/Cluster_Init_Trafodion

exit 0