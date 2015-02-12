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

# install or uninstall
action="$1"

# work location - required for traf-functions.sh
WORKSPACE="$2"

# required tarballs for install
instball="$3"
trafball="$4"
dcsball="$5"
# dcs server number
dcscnt="$6"
# optional sql regression tarball
regball="$7"

source "/usr/local/bin/traf-functions.sh"
log_banner "Trafodion $action"

set -x

if [[ $action == "install" ]]
then
  # first clean out hbase from previous tests
  sudo /usr/local/bin/hbase-clean.sh initialize || exit 1

  sudo rm -rf /var/log/trafodion/* # clean out logs from any prior jobs
  sudo rm -rf $INSTLOC $RUNLOC || exit 1

  sudo mkdir $INSTLOC || exit 1
  sudo mkdir $RUNLOC || exit 1

  sudo chown tinstall $INSTLOC || exit 1

  cp "$instball" $INSTLOC || exit 1

  cd $INSTLOC
  tar xzf $(basename $instball) || exit 1

  # Old (multi-script) installer vs. New (single-script) installer
  if [[ -f ./installer/trafodion_setup ]]
  then
    # Trafodion set-up
    echo "accept" | 
       ./installer/trafodion_setup --nodes "$(hostname -s)"
    ret=$?

    # Trafodion mods
    if [[ $ret == 0 ]]
    then
      ./installer/trafodion_mods --trafodion_build "$trafball"
      ret=$?
    fi

    # Trafodion installer
    if [[ $ret == 0 ]]
    then
      # old installer on ambari requires manual restart of hbase
      if rpm -q ambari-server >/dev/null
      then
        sudo /usr/local/bin/hbase-clean.sh restart
      fi

      # trafodion user should exist after setup
      sudo chown trafodion $RUNLOC

      # -i logs into home dir
      sudo -n -i -u trafodion ./trafodion_installer --dcs_servers $dcscnt --init_trafodion \
	       --build "$trafball" \
	       --dcs_build "$dcsball" \
	       --install_path $RUNLOC
      ret=$?
    fi
  else
    # prep config file  
    cp ./installer/trafodion_config_default ./tc
    echo "NODE_LIST=$(hostname -s)" >> ./tc
    echo "node_count=1" >> ./tc
    echo "LOCAL_WORKDIR=$INSTLOC/installer" >> ./tc
    echo "OPENSTACK_VM=1" >> ./tc
    echo "TRAF_BUILD=$trafball" >> ./tc
    echo "DCS_BUILD=$dcsball" >> ./tc
    echo "SQ_ROOT=$RUNLOC" >> ./tc
    echo "START=Y" >> ./tc
    echo "INIT_TRAFODION=Y" >> ./tc
    echo "DCS_SERVERS_PARM=$dcscnt" >> ./tc
    echo "CLUSTER_NAME=trafcluster" >> ./tc
    if rpm -q cloudera-manager-server >/dev/null
    then
      echo "URL=$(hostname -f):7180" >> ./tc
      echo "HADOOP_TYPE=cloudera" >> ./tc
    else
      echo "URL=$(hostname -f):8080" >> ./tc
      echo "HADOOP_TYPE=hortonworks" >> ./tc
    fi

    ./installer/trafodion_install --accept_license --config_file ./tc
    ret=$?
  fi
  # save installer logs
  sudo -n -u jenkins mkdir -p $WORKSPACE/var_log_trafodion
  sudo chmod -R +r /var/log/trafodion
  sudo -n -u jenkins cp /var/log/trafodion/* $WORKSPACE/var_log_trafodion/

  if [[ $ret == 0 ]]
  then
    # Extra dir needed by hive regressions
    # must be HDFS superuser (hdfs) to chown
    sudo -n -u hive hadoop dfs -chmod +rx -p /user/hive
    sudo -n -u hive hadoop dfs -mkdir -p /user/hive/exttables
    sudo -n -u hdfs hadoop dfs -chown trafodion /user/hive/exttables
    # trafodion user directory must exist to accomodate Trash folder 
    # (or every use of hdfs rm has to use -skipTrash option)
    sudo -n -u hdfs hadoop dfs -mkdir -p /user/trafodion
    sudo -n -u hdfs hadoop dfs -chown trafodion /user/trafodion
    # /lobs needed by executor
    sudo -n -u hdfs hadoop dfs -mkdir -p /lobs
    sudo -n -u hdfs hadoop dfs -chown trafodion /lobs
  fi

  # Dev regressions
  if [[ $ret == 0 && -n "$regball" ]]
  then
    cd $RUNLOC
    sudo -n -u trafodion tar xf $regball
  fi
  # make system logs read-able in case of early exit of job
  sudo chmod -R a+rX $RUNLOC

  exit $ret

elif [[ $action == "uninstall" ]]
then
  # make system logs world-readable for archival
  sudo chmod -R a+rX $RUNLOC

  # Same location as setup
  cd $INSTLOC
  ./installer/trafodion_uninstaller --all \
                --instance $RUNLOC
  exit $?

else
  echo "Error: unsupported action: $action"
  exit 1
fi
