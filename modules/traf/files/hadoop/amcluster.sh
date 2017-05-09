#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2015 Hewlett-Packard Development Company, L.P.
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

# Interact with Ambari for initial cluster set-up
# Simple single-node cluster for test environment

PATH="/bin:/usr/bin"

log_banner "Checking Cluster Configuration"
echo "*** Checking Cluster Configuration"

# Distro 

if [[ "$1" == "-d" ]]
then
  mode="Delete"
  shift
else
  mode="Create"
fi

# previously saved?
if [[ -r /var/local/TrafTestDistro ]]
then
  Vers="$(</var/local/TrafTestDistro)"
  echo "Retrieving distro from /var/local/TrafTestDistro: $Vers"
else
  Vers="$1"
  if [[ ! $Vers =~ ^HDP-[0-9][.0-9]+$ ]]
  then
    echo "Error: Distro not specified in /var/local/TrafTestDistro nor on command line"
    echo "Error: Usage: $0 HDP-<full-version-number>"
    exit 1
  fi
  echo "$Vers" > /var/local/TrafTestDistro
fi

Stack=$(echo $Vers | sed 's%\-%/versions/%')

# curl options
URL="http://localhost:8080/api/v1"
# silent (no progress msgs), default user/pw 
Opts="-su admin:admin"

Read="$Opts"
Create="-X POST -H X-Requested-By:traf $Opts"
Update="-X PUT -H X-Requested-By:traf $Opts"
Delete="-X DELETE -H X-Requested-By:traf $Opts"


# Function - poll command until it completes and report results
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

###############################
# Main

# service list
if [[ $Vers == "HDP-2.1" ]]
then
  services="HDFS HIVE HBASE ZOOKEEPER MAPREDUCE2 YARN WEBHCAT HCATALOG TEZ"
else
  services="HDFS HIVE HBASE ZOOKEEPER MAPREDUCE2 YARN TEZ"
fi

# Check that we can talk to Ambari server
curl $Read $URL/clusters | grep -q href
if [[ $? != 0 ]]
then
  set -x
  /sbin/service ambari-server start
  /sbin/service ambari-agent start
  set +x
  echo "Waiting for Ambari to respond"
  i=0
  AM="DOWN"
  while (( i < 25 ))
  do
    curl $Read $URL/clusters | grep -q href
    if [[ $? == 0 ]]
    then
      AM="UP"
      break
    fi
    ((i+=1))
    sleep 15
  done
  if [[ $AM == "DOWN" ]]
  then
    echo "Error: cannot contact ambari server"
    exit 2
  fi
fi

if [[ $mode = "Delete" ]]
then
  # stop all services
  for serv in $services
  do
    State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
    if [[ $State == "STARTED" ]] 
    then
      echo "*** Stopping $serv"
      reqINSTALL='{"RequestInfo": {"context" :"$serv Stop"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}'
      RID=$(curl $Update -d "$reqINSTALL" $URL/clusters/trafcluster/services/$serv | jq -r '.Requests.id')
      am_cmd "$RID" "$serv Stop"
      # Check status
      State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
      if [[ $State != "INSTALLED" ]]
      then
        echo "Error: $serv not stopped"
        exit 2
      fi
    fi
  done
  echo "Deleting cluster: trafcluster"
  curl $Delete $URL/clusters/trafcluster 
  exit $?
fi

# Create Cluster 
Cluster="$(curl $Read $URL/clusters | jq -r '.items[].Clusters.cluster_name')"

if [[ $Cluster == "null" || -z "$Cluster" ]]
then
  echo "Creating cluster: trafcluster"
  curl $Create -d '{ "Clusters" : {
		      "version" : "'$Vers'"
		    } }
		  ' $URL/clusters/trafcluster 
  Cluster=$(curl $Read $URL/clusters/trafcluster | jq -r '.Clusters.cluster_name')
  if [[ $Cluster != "trafcluster" ]]
  then
    echo "Error: failed to create cluster"
    exit 2
  fi
fi

# Create Host 
hn=$(hostname -f)
Host="$(curl $Read $URL/clusters/trafcluster/hosts/$hn | jq -r '.Hosts.host_name')"

if [[ $Host != "$hn" ]]
then
  echo "Creating host: $hn"
  curl $Create $URL/clusters/trafcluster/hosts/$hn
  Host="$(curl $Read $URL/clusters/trafcluster/hosts/$hn | jq -r '.Hosts.host_name')"
  if [[ $Host != "$hn" ]]
  then
    echo "Error: failed to create $hn host"
    exit 2
  fi
fi

# Create Services 
for serv in $services
do
  Service="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.service_name')"

  if [[ $Service == "null" ]]
  then
    echo "Creating service: $serv"
    curl $Create $URL/clusters/trafcluster/services/$serv
    Service="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.service_name')"
    if [[ $Service != "$serv" ]]
    then
      echo "Error: failed to create $serv service"
      exit 2
    fi
  fi
done

# Configurations

function initconfig {
  level=$1  # service level or stack level
  ctype=$2

  ## does the config type exist?
  Config=$(curl $Read "$URL/clusters/trafcluster/configurations?type=${ctype}" | jq -r '.items[0].type')
  if [[ $Config != $ctype ]]
  then
    echo "Retrieving stack defaults for config type $ctype"
    if [[ $level == "service" ]]
    then
      query="services?configurations/StackConfigurations/type=${ctype}.xml" # retrieve all config properties of this type
      query+="&fields=configurations/StackConfigurations/property_value" # value field not shown by default
      jsonparse='.items[].configurations[].StackConfigurations|{(.property_name):.property_value}'
    else
      query="configurations?StackLevelConfigurations/type=${ctype}.xml" 
      query+="&fields=StackLevelConfigurations/property_value" 
      jsonparse='.items[].StackLevelConfigurations|{(.property_name):.property_value}'
    fi
    # parse to give property name-value pairs
    Props=$(curl $Read "$URL/stacks/$Stack/$query" | jq -r $jsonparse)
    # change format to single list
    Proplist=$(echo $Props | sed 's/ } { "/ , "/g')
    [[ -z "$Proplist" ]] && Proplist="{}"

    # create the first version of this config type, with default values
    echo "Creating initial config type $ctype"
    echo "Properties: $Proplist"
    reqdata='{"type" : "'$ctype'", "tag" : "version001", "properties" : '$Proplist' }'
    curl $Create -d "$reqdata" $URL/clusters/trafcluster/configurations

    # verify it was created
    Config=$(curl $Read "$URL/clusters/trafcluster/configurations?type=${ctype}" | jq -r '.items[0].type')
    if [[ $Config != $ctype ]]
    then
      echo "Error: failed to create $ctype config"
      exit 2
    fi
  fi

  ## has the config type been applied to the cluster?
  ## it may not be the initial version (tag), but it should not be null
  Config=$(curl $Read $URL/clusters/trafcluster?fields=Clusters/desired_configs/$ctype \
    		| jq -r '.Clusters.desired_configs|.["'${ctype}'"].tag') # special syntax due to '-' in json key
  if [[ $Config == "null" ]]
  then
    echo "Applying $ctype config"
    reqdata='{"Clusters" : {"desired_config" : {"type" : "'$ctype'", "tag" : "version001"}}}'
    curl $Update -d "$reqdata" $URL/clusters/trafcluster
    # verify
    Config=$(curl $Read $URL/clusters/trafcluster?fields=Clusters/desired_configs/$ctype \
    		| jq -r '.Clusters.desired_configs|.["'${ctype}'"].tag') # special syntax due to '-' in json key
    if [[ $Config != "version001" ]]
    then
      echo "Error: failed to apply desired_config $ctype version001"
      exit 2
    fi
  fi
}

if [[ $Vers == "HDP-2.1" ]]
then
  conftypes="capacity-scheduler core-site global hbase-log4j hbase-site hdfs-log4j hdfs-site hive-exec-log4j"
  conftypes+=" hive-log4j hive-site mapred-site mapreduce2-log4j tez-site webhcat-site yarn-log4j yarn-site"
  conftypes+=" zoo.cfg zookeeper-log4j"
else
  # global replaced by *-env
  conftypes="capacity-scheduler core-site hadoop-env hbase-log4j hbase-site hbase-env hcat-env hdfs-log4j hdfs-site"
  conftypes+=" hive-env hive-exec-log4j hive-log4j hive-site hiveserver2-site mapred-env mapred-site tez-env tez-site"
  conftypes+=" webhcat-env webhcat-site yarn-env yarn-log4j yarn-site zoo.cfg zookeeper-env zookeeper-log4j"
  # required by ambari2.4 (DB consistency check)
  conftypes+=" ranger-yarn-policymgr-ssl ranger-yarn-audit ranger-yarn-security ranger-yarn-plugin-properties"
  conftypes+=" ranger-hbase-security hbase-policy ranger-hbase-policymgr-ssl ranger-hbase-audit ranger-hbase-plugin-properties"
  conftypes+=" ssl-server ranger-hdfs-audit ranger-hdfs-plugin-properties ssl-client ranger-hdfs-policymgr-ssl hadoop-policy ranger-hdfs-security"
  conftypes+=" ranger-hive-plugin-properties ranger-hive-policymgr-ssl ranger-hive-audit webhcat-log4j ranger-hive-security"
fi

for ctype in $conftypes
do
  initconfig "service" "$ctype"
done

# cluster env replacing global
if [[ $Vers != "HDP-2.1" ]]
then
  initconfig "stack" "cluster-env"
fi

# Local non-default config changes

getCONF="/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin get localhost trafcluster"
setCONF="/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin set localhost trafcluster"

function setconfig {
  ctype="$1"
  cprop="$2"
  cvalue="$3"

  #retrieve and parse value of property 
  CVal=$($getCONF $ctype | grep '"'${cprop}'"' | sed 's/^.*:\s*"\(.*\)"/\1/;s/,$//')
  if [[ $CVal != "$cvalue" ]]
  then
    echo "Setting $cprop config"
    # set and apply new config
    $setCONF "$ctype" "$cprop" "$cvalue" || exit $?
  fi
}

# single-node setting
setconfig hdfs-site dfs.replication 1

if [[ $Vers == "HDP-2.1" ]]
then
  # these not in the defaults for some reason
  setconfig global user_group "hadoop"
  setconfig global proxyuser_group "users"
  setconfig global smokeuser "ambari-qa"
  # java heapsize default was "1024" for most services, but
  # a unit is expected on some. On others, ambari scripts add it.
  # These are the ones that need it added. AMBARI-4933
  setconfig global "dtnode_heapsize" "1024m"
  setconfig global "namenode_heapsize" "1024m"
  setconfig global "namenode_opt_newsize" "200m"
  setconfig global "namenode_opt_maxnewsize" "200m"
  setconfig global "hbase_master_heapsize" "1024m"
  setconfig global "hbase_regionserver_heapsize" "1024m"
else
  setconfig hadoop-env "dtnode_heapsize" "1024m"
  setconfig hadoop-env "namenode_heapsize" "1024m"
  setconfig hadoop-env "namenode_opt_newsize" "200m"
  setconfig hadoop-env "namenode_opt_maxnewsize" "200m"
  setconfig hbase-env "hbase_master_heapsize" "1024m"
  setconfig hbase-env "hbase_regionserver_heapsize" "1024m"
  setconfig zookeeper-env "zk_server_heapsize" "1024m"
fi

if [[ $Vers == "HDP-2.1" ]]
then
  setconfig global "hive_metastore_user_passwd" "notsecure"
else
  setconfig hive-site "hive_metastore_user_passwd" "notsecure"
fi
setconfig hive-site "javax.jdo.option.ConnectionPassword" "notsecure"

if [[ $Vers == "HDP-2.2" ]]
then
  setconfig capacity-scheduler "yarn.scheduler.capacity.root.accessible-node-labels.default.capacity" "1"
  setconfig capacity-scheduler "yarn.scheduler.capacity.root.accessible-node-labels.default.maximum-capacity" "1"
fi

rm -f doSet_*.json # clean up temp files left by configs.sh


# Service Components, Host Components

reqinstall='{"HostRoles" : {"state" : "INSTALLED" }}'

# order matters somewhat
# e.g., yarn resource manager must before mapreduce client
# for HDP2.3, HIVE_METASTORE must come before other hive components
if [[ $Vers == "HDP-2.1" ]]
then
  hcat="WEBHCAT:WEBHCAT_SERVER HCATALOG:HCAT"
else
  hcat="HIVE:WEBHCAT_SERVER HIVE:HCAT"
fi

comp_list="HDFS:DATANODE HDFS:NAMENODE HDFS:SECONDARY_NAMENODE HDFS:HDFS_CLIENT \
      ZOOKEEPER:ZOOKEEPER_SERVER \
      YARN:APP_TIMELINE_SERVER YARN:NODEMANAGER YARN:RESOURCEMANAGER YARN:YARN_CLIENT \
      MAPREDUCE2:HISTORYSERVER MAPREDUCE2:MAPREDUCE2_CLIENT \
      HIVE:HIVE_METASTORE HIVE:HIVE_SERVER HIVE:MYSQL_SERVER HIVE:HIVE_CLIENT $hcat \
      HBASE:HBASE_MASTER HBASE:HBASE_REGIONSERVER HBASE:HBASE_CLIENT \
      TEZ:TEZ_CLIENT"
for sc in $comp_list
do
  serv=${sc%:*}
  comp=${sc#*:}

  HComp="$(curl $Read $URL/clusters/trafcluster/hosts/$hn/host_components/$comp \
                | jq -r '.HostRoles.component_name')"

  if [[ $HComp == "null" ]]
  then
    echo "Creating $comp service & host component"
    # create service component
    curl $Create $URL/clusters/trafcluster/services/$serv/components/$comp
    # create host component
    curl $Create $URL/clusters/trafcluster/hosts/$hn/host_components/$comp
    HComp="$(curl $Read $URL/clusters/trafcluster/hosts/$hn/host_components/$comp \
                | jq -r '.HostRoles.component_name')"
    if [[ ! ($HComp =~ $comp) ]]
    then
      echo "Error: failed to create $comp host component"
      exit 2
    fi
  fi
done

for sc in $comp_list
do
  serv=${sc%:*}
  comp=${sc#*:}

  HCState="$(curl $Read $URL/clusters/trafcluster/hosts/$hn/host_components/$comp \
                      | jq -r '.HostRoles.state')"
  if [[ $HCState =~ INIT|INSTALL_FAILED ]]
  then
    RID=$(curl $Update -d "$reqinstall" $URL/clusters/trafcluster/hosts/$hn/host_components/$comp \
		| jq -r '.Requests.id')
    am_cmd "$RID" "Install $comp"  || exit 2
  fi
done

log_banner "Start Services and Delete HBase data"

# Start services
# required for services with master or slave components
# not for those that have only client components (e.g. TEZ)
reqINSTALL='{"RequestInfo": {"context" :"Initial Install"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}'
reqSTART='{"RequestInfo": {"context" :"Initial Start"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}'

function start_service() {
  serv=$1

  for retry in 0 30 60 120 240
  do
    State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
    if [[ $State == "STARTED" ]]
    then
      return 0
    else
      echo "$serv not started, waiting $retry seconds"
      sleep $retry
    fi

    # first, move service (and components) from INIT to INSTALLED
    echo "Installing $serv (just in case all components are not INSTALLED)"
    RID=$(curl $Update -d "$reqINSTALL" $URL/clusters/trafcluster/services/${serv} | jq -r '.Requests.id')
    am_cmd "$RID" "$serv Install"
    # then from INSTALLED to STARTED
    echo "*** Starting $serv"
    RID=$(curl $Update -d "$reqSTART" $URL/clusters/trafcluster/services/${serv} | jq -r '.Requests.id')
    am_cmd "$RID" "$serv Start"
  done

  # Check status
  State="$(curl $Read $URL/clusters/trafcluster/services/$serv | jq -r '.ServiceInfo.state')"
  if [[ $State != "STARTED" ]] 
  then
    echo "Error: $serv not started"
    exit 2
  fi

}

start_service ZOOKEEPER

# HDFS
State="$(curl $Read $URL/clusters/trafcluster/services/HDFS | jq -r '.ServiceInfo.state')"
if [[ $State == "STARTED" ]] 
then
  # make sure we are not in HDFS safemode
  mode="$(hdfs dfsadmin -safemode get)"
  if [[ $mode =~ ON ]]
  then
    sudo -u hdfs hdfs dfsadmin -safemode leave
  fi
else
  start_service HDFS

  # wait for safemode so we can modify hdfs data
  sudo -u hdfs hdfs dfsadmin -safemode wait
fi

### HBase data cleaned up every time
State="$(curl $Read $URL/clusters/trafcluster/services/HBASE | jq -r '.ServiceInfo.state')"
if [[ $State == "STARTED" ]] 
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

echo "*** Removing HBase Data"

# data locations for Ambari
hdata="/apps/hbase/data /bulkload /lobs /trafodion_backups" # HDFS
zkdata="/hbase-unsecure" # zookeeper

sudo -u hdfs /usr/bin/hdfs dfs -rm -r -f -skipTrash $hdata || exit $?
sudo -u zookeeper /usr/bin/hbase zkcli rmr $zkdata 2>/dev/null || exit $?

# clean up logs so we can save only what is logged for this run
sudo -u hbase rm -rf /var/log/hbase/*

# recreate root
sudo -u hdfs /usr/bin/hdfs dfs -mkdir -p $hdata || exit $?
sudo -u hdfs /usr/bin/hdfs dfs -chown hbase:hbase $hdata || exit $?

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

# revert to initial hbase-site config so we are not running with trx
  echo "*** Applying hbase-site initial config"
  reqdata='{"Clusters" : {"desired_config" : {"type" : "hbase-site", "tag" : "version001"}}}'
  curl $Update --data "$reqdata" $URL/clusters/trafcluster


start_service YARN
start_service MAPREDUCE2
start_service HIVE
if [[ $Vers == "HDP-2.1" ]]
then
  start_service WEBHCAT
fi
start_service HBASE

echo "*** Cluster Check Complete"

exit 0

