#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2013-2015 Hewlett-Packard Development Company, L.P.
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

mode="$1"
if [[ "$mode" == "restart" ]]
then
  echo "Action: Restart HBase service"
elif [[ "$mode" == "initialize" ]]
then
  echo "Action: Destroy HBase data, initialize, and start service"
else
  echo "Error: unrecognized mode: $mode"
  exit 1
fi

# Clean up all HBase data to start fresh test run

if rpm -q cloudera-manager-server >/dev/null
then
  Manager="Cloudera"
  URL="http://localhost:7180/api/v7"
  Opts="-su admin:admin"
  Read="$Opts"
  Create="-X POST -H Content-Type:application/json $Opts"
  Update="-X PUT  -H Content-Type:application/json $Opts"
elif rpm -q ambari-server >/dev/null
then
  Manager="Ambari"
  URL="http://localhost:8080/api/v1"
  Opts="-su admin:admin -H X-Requested-By:traf"
  Read="$Opts"
  Create="-X POST $Opts"
  Update="-X PUT  $Opts"
else
  echo "Error: No cluster manager installed"
  exit 1
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
# ambari command - poll command until it completes and report results
function am_cmd {
  id=$1
  action="$2"
  if [[ $id =~ [0-9]+ ]]
  then
    status=''
    until [[ $status =~ COMPLETED|FAILED|TIMEDOUT|ABORTED ]]
    do
      sleep 2
      status=$(curl $Read $URL/clusters/trafcluster/requests/$id | jq -r '.Requests.request_status')
    done
    echo "$action result: $status"
    if [[ $status == "COMPLETED" ]]
    then
      return 0
    else
      echo "Detailed status for request id $id ..."
      tasks=$(curl $Read $URL/clusters/trafcluster/requests/$id/tasks | jq -r '.items[].Tasks.id')
      for t in $tasks
      do
        echo "Task id $t Command, Status, StdErr ..."
        curl $Read $URL/clusters/trafcluster/requests/$id/tasks/$t | \
          jq -r '.Tasks.command_detail,.Tasks.status,.Tasks.stderr'
      done
      return 1
    fi
  else
    echo "$action command did not launch"
    return 2
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
  echo "*** Stopping HBase"
  reqINSTALL='{"RequestInfo": {"context" :"HBase Stop"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}'
  RID=$(curl $Update -d "$reqINSTALL" $URL/clusters/trafcluster/services/HBASE | jq -r '.Requests.id')
  am_cmd "$RID" "HBASE Stop"
  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/HBASE | jq -r '.ServiceInfo.state')"
  if [[ $State != "INSTALLED" ]]
  then
    echo "Error: HBASE not stopped"
    exit 2
  fi
fi

if [[ "$mode" == "initialize" ]]
then
  ####
  # Make sure HDFS and zookeeper are running
  #

  if [[ $Manager == "Cloudera" ]]
  then
    for serv in hdfs trafZOO
    do
      State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
      if [[ $State == "STOPPED" ]]
      then
        echo "Starting $serv"
        CID=$(curl $Create $URL/clusters/trafcluster/services/$serv/commands/start | jq -r '.id')
        cm_cmd $CID "$serv Start"
        # Check status
        State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.serviceState')"
        if [[ $State =~ STOP ]] # stopped, stopping
        then
          echo "Error: $serv service not started"
          exit 2
        fi
      fi
    done
  elif [[ $Manager == "Ambari" ]]
  then
    reqINSTALL='{"RequestInfo": {"context" :"Check Start"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}'
    reqSTART='{"RequestInfo": {"context" :"Check Start"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}'

    for serv in ZOOKEEPER HDFS
    do
      State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
      if [[ $State != "STARTED" ]]
      then
        # first, move service (and components) to INSTALLED
        echo "Installing $serv (just in case all components are not INSTALLED)"
        RID=$(curl $Update -d "$reqINSTALL" $URL/clusters/trafcluster/services/${serv} | jq -r '.Requests.id')
        am_cmd "$RID" "$serv Install"
        # then from INSTALLED to STARTED
        echo "Starting $serv"
        RID=$(curl $Update -d "$reqSTART" $URL/clusters/trafcluster/services/${serv} | jq -r '.Requests.id')
        am_cmd "$RID" "$serv Start"
      fi
      # Check status
      State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
      if [[ $State != "STARTED" ]]
      then
        echo "Error: $serv not started"
        exit 2
      fi
    done
  fi

  # make sure we are not in HDFS safemode
  mode="$(hdfs dfsadmin -safemode get)"
  if [[ $mode =~ ON ]]
  then
    sudo -u hdfs hdfs dfsadmin -safemode leave
  fi

  ####
  # Clear Data
  #

  echo "*** Clearing /hbase data from HDFS & ZooKeeper"
  set -x
  if [[ $Manager == "Cloudera" ]]
  then
    hdata="/hbase"
    zkdata="/hbase"
  elif [[ $Manager == "Ambari" ]]
  then
    hdata="/apps/hbase/data"
    zkdata="/hbase-unsecure"
  fi
  sudo -u hdfs /usr/bin/hadoop fs -rm -r -f -skipTrash $hdata || exit $?
  sudo -u hdfs /usr/bin/hadoop fs -mkdir $hdata || exit $?
  sudo -u hdfs /usr/bin/hadoop fs -chown hbase:hbase $hdata || exit $?
  sudo -u zookeeper /usr/bin/hbase zkcli rmr $zkdata 2>/dev/null || exit $?
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
    echo "*** Applying hbase-site initial config"
    reqdata='{"Clusters" : {"desired_config" : {"type" : "hbase-site", "tag" : "version001"}}}'
    curl $Update --data "$reqdata" $URL/clusters/trafcluster
  fi


  ####
  # Clear caches by re-starting cluster
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
    echo "*** Re-starting cluster services"
    reqINSTALL='{"RequestInfo": {"context" :"Cluster Stop"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}'
    reqSTART='{"RequestInfo": {"context" :"Cluster Start"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}'
    for serv in WEBHCAT HIVE MAPREDUCE2 YARN
    do
      RID=$(curl $Update -d "$reqINSTALL" $URL/clusters/trafcluster/services/$serv | jq -r '.Requests.id')
      am_cmd "$RID" "$serv Stop"
    done
    for serv in YARN MAPREDUCE2 HIVE WEBHCAT HBASE
    do
      RID=$(curl $Update -d "$reqSTART" $URL/clusters/trafcluster/services/$serv | jq -r '.Requests.id')
      am_cmd "$RID" "$serv Start"
    done

    # Check status
    State="$(curl $Read $URL/clusters/trafcluster/services/HBASE | jq -r '.ServiceInfo.state')"
    if [[ $State != "STARTED" ]]
    then
      echo "Error: HBASE not started"
      exit 2
    fi
  fi
fi

# support restart only for Ambari
if [[ $mode == "restart" && $Manager == "Ambari" ]]
then
  echo "*** Starting HBase"
  reqSTART='{"RequestInfo": {"context" :"HBase Start"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}'
  RID=$(curl $Update -d "$reqSTART" $URL/clusters/trafcluster/services/HBASE | jq -r '.Requests.id')
  am_cmd "$RID" "HBASE Start"
  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/HBASE | jq -r '.ServiceInfo.state')"
  if [[ $State != "STARTED" ]]
  then
    echo "Error: HBASE not started"
    exit 2
  fi
fi

exit 0
