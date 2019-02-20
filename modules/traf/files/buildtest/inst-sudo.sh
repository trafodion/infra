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

# optional ldap config
if [[ "$1" == "--ldap" ]]
then
  LDAP="true"
  shift
else
  LDAP="false"
fi

# install or uninstall or pyinstall or pyuninstall
action="$1"

# work location - required for traf-functions.sh
WORKSPACE="$2"

# required tarballs for install
instball="$3"
trafball="$4"
restball="$5"
dcsball="$6"
# dcs server number
dcscnt="$7"
# optional sql regression tarball
regball="$8"
# java ver
TRAFJAVA="$9"

source "/usr/local/bin/traf-functions.sh"
log_banner "Trafodion $action"

# for debugging purposes - find port conflicts
function check_port() {
  set +x
  portnum=$1

  echo "Check usage of port $portnum"

  # ss will let us know if port is in use, and -p option will give us process info
  # (must be root to get info if we don't own the process)
  cmd="sudo -n /usr/sbin/ss -lp src *:$portnum"

  pcount=$($cmd | wc -l)
  pids=$($cmd | sed -n '/users:/s/^.*users:((.*,\([0-9]*\),.*$/\1/p')

  if [[ $pcount > 1 ]] # always get header line
  then
    echo "Warning: found port $portnum in use"
    $cmd
  fi
  if [[ -n $pids ]]
  then
    echo "Warning: processes using port $portnum"
    ps -f $pids
  fi
  set -x
}
set -x

if [[ $action == "install" ]]
then
  sudo rm -rf /var/log/trafodion/* # clean out logs from any prior jobs
  sudo rm -rf /etc/trafodion
  sudo rm -rf $INSTLOC $RUNLOC || exit 1

  sudo mkdir $INSTLOC || exit 1
  sudo mkdir $RUNLOC || exit 1

  sudo chown tinstall $INSTLOC || exit 1

  cp "$instball" $INSTLOC || exit 1

  cd $INSTLOC
  tar xzf $(basename $instball) || exit 1

  # prep ldap config
  sed -e 's/LdapHostname:/LdapHostname:static.trafodion.org/' \
      -e 's/UniqueIdentifier:/UniqueIdentifier:uid=,ou=users,dc=trafldap,dc=com/' \
      ./installer/traf_authentication_conf_default > ./installer/traf_auth_config

  # prep config file  
  cp ./installer/trafodion_config_default ./Install_Config
  echo "NODE_LIST=$(hostname -s)" >> ./Install_Config
  echo "HADOOP_NODES=$(hostname -s)" >> ./Install_Config
  echo "HDFS_NODES=$(hostname -s)" >> ./Install_Config
  echo "HBASE_NODES=$(hostname -s)" >> ./Install_Config
  echo "MY_HADOOP_NODES=\"-w $(hostname -s)\"" >> ./Install_Config
  echo "node_count=1" >> ./Install_Config
  echo "hadoop_node_count=1" >> ./Install_Config
  echo "LOCAL_WORKDIR=$INSTLOC/installer" >> ./Install_Config
  echo "OPENSTACK_VM=1" >> ./Install_Config
  # As of 2.0.0, single package tar
  if [[ $(basename $trafball) =~ ^apache- ]]
  then
    echo "TRAF_PACKAGE=$trafball" >> ./Install_Config
    echo "ONE_TAR_INSTALL=Y" >> ./Install_Config
  else
    echo "TRAF_BUILD=$trafball" >> ./Install_Config
    echo "REST_BUILD=$restball" >> ./Install_Config  ## may be empty for pre-1.1 builds
    echo "DCS_BUILD=$dcsball" >> ./Install_Config
  fi
  echo "SQ_ROOT=$RUNLOC" >> ./Install_Config
  echo "TRAF_HOME=$RUNLOC" >> ./Install_Config
  echo "START=Y" >> ./Install_Config
  echo "INIT_TRAFODION=Y" >> ./Install_Config
  echo "DCS_SERVERS_PARM=$dcscnt" >> ./Install_Config
  echo "CLUSTER_NAME=trafcluster" >> ./Install_Config
  if rpm -q cloudera-manager-server >/dev/null
  then
    echo "URL=$(hostname -f):7180" >> ./Install_Config
    echo "HADOOP_TYPE=cloudera" >> ./Install_Config
  elif rpm -q ambari-server >/dev/null
  then
    echo "URL=$(hostname -f):8080" >> ./Install_Config
    echo "HADOOP_TYPE=hortonworks" >> ./Install_Config
  else
    echo "HADOOP_TYPE=apache" >> ./Install_Config
    echo "HADOOP_PREFIX=/opt/hadoop" >> ./Install_Config
    echo "HBASE_HOME=/opt/hbase" >> ./Install_Config
    echo "ZOO_HOME=/opt/zookeeper" >> ./Install_Config
    echo "HIVE_HOME=/opt/hive" >> ./Install_Config
    echo "HDFS_USER=tinstall" >> ./Install_Config
    echo "HBASE_USER=tinstall" >> ./Install_Config
    echo "HBASE_GROUP=tinstall" >> ./Install_Config
    echo "ZOO_USER=tinstall" >> ./Install_Config
  fi
  if [[ $LDAP == "true" ]]
  then
    echo "LDAP_SECURITY=Y" >> ./Install_Config
    echo "LDAP_AUTH_FILE=traf_auth_config" >> ./Install_Config
  fi
  # no SUSE yet
  echo "SUSE_LINUX=false" >> ./Install_Config
  echo "JAVA_HOME=$TRAFJAVA" >> ./Install_Config
  # DCS/Cloud
  echo "CLOUD_CONFIG=Y" >> ./Install_Config
  echo "CLOUD_TYPE=1" >> ./Install_Config
  echo "AWS_CLOUD=true" >> ./Install_Config


  check_port 23400
  check_port 24400

  echo "*** Calling trafodion_install"
  ./installer/trafodion_install --accept_license --config_file ./Install_Config
  ret=$?

  check_port 23400
  check_port 24400

  # save installer logs
  sudo -n -u jenkins mkdir -p $WORKSPACE/var_log_trafodion
  sudo chmod -R +r /var/log/trafodion
  sudo -n -u jenkins cp /var/log/trafodion/* $WORKSPACE/var_log_trafodion/

  if [[ $ret == 0 ]]
  then
    # Extra dir needed by hive regressions -- for 2.1 and earlier
    # must be HDFS superuser (hdfs) to chown
    sudo -n -u hive hadoop dfs -chmod +rx -p /user/hive
    sudo -n -u hive hadoop dfs -mkdir -p /user/hive/exttables
    sudo -n -u hdfs hadoop dfs -chown trafodion /user/hive/exttables
    # trafodion user directory must exist to accomodate Trash folder 
    # (or every use of hdfs rm has to use -skipTrash option)
    sudo -n -u hdfs hadoop dfs -mkdir -p /user/trafodion
    sudo -n -u hdfs hadoop dfs -chown trafodion /user/trafodion

    if [[ $LDAP == "true" ]]
    then
      echo "register user qa001;" | sudo -n -i -u trafodion 'sqlci'
    fi
  fi

  # Dev regressions
  if [[ $ret == 0 && -n "$regball" ]]
  then
    echo "*** Installing regressions"
    cd $RUNLOC
    sudo -n -u trafodion tar xf $regball
  fi
  # make system logs read-able in case of early exit of job
  sudo chmod -R a+rX $RUNLOC ~trafodion

  # create alternate directory for Maven Local repo for T2 tests
  if [[ ! -d /var/local/traf_mvn_repo ]]; then
    sudo mkdir /var/local/traf_mvn_repo
  fi
  sudo chown -R trafodion:trafodion /var/local/traf_mvn_repo

  exit $ret

elif [[ $action == "pyinstall" ]]
then
  sudo rm -rf /var/log/trafodion/* # clean out logs from any prior jobs
  sudo rm -rf /etc/trafodion
  sudo rm -rf $INSTLOC $RUNLOC || exit 1

  sudo mkdir $INSTLOC || exit 1

  sudo chown tinstall $INSTLOC || exit 1

  cp "$instball" $INSTLOC || exit 1

  cd $INSTLOC
  tar xzf $(basename $instball) || exit 1

  cp ./python-installer/configs/db_config_default.ini ./Install_Config
  echo "node_list = $(hostname -s)" >> ./Install_Config
  echo "first_rsnode = $(hostname -s)" >> ./Install_Config
  echo "ldap_identifiers = uid=,ou=users,dc=trafldap,dc=com" >> ./Install_Config
  echo "ldap_security = Y" >> ./Install_Config
  echo "ldap_hosts = static.trafodion.org" >> ./Install_Config
  if rpm -q cloudera-manager-server >/dev/null
  then
    echo "mgr_url = $(hostname -f):7180" >> ./Install_Config
  elif rpm -q ambari-server >/dev/null
  then
    echo "mgr_url = $(hostname -f):8080" >> ./Install_Config
  fi
  echo "java_home = $TRAFJAVA" >> ./Install_Config
  echo "traf_package = $trafball" >> ./Install_Config
  echo "dcs_cnt_per_node = $dcscnt" >> ./Install_Config

  sudo mkdir -p $WORKSPACE/home
  echo "home_dir = $WORKSPACE/home" >> ./Install_Config
  echo "traf_dirname = traf_run" >> ./Install_Config
  echo "traf_log = $WORKSPACE/traf_run/logs" >> ./Install_Config
  echo "traf_var = $WORKSPACE/traf_run/tmp" >> ./Install_Config
  ## bogus param -- TRAFODION-2510
  echo "db_admin_pwd = foobar" >> ./Install_Config

  echo "*** Calling db_install.py"
  ./python-installer/db_install.py --verbose --silent --config-file ./Install_Config
  ret=$?

  sudo ln -s $WORKSPACE/home/trafodion/traf_run $RUNLOC

  if [[ $ret == 0 ]]
  then
    if [[ $LDAP == "true" ]]
    then
      echo "register user qa001;" | sudo -n -i -u trafodion 'sqlci'
    fi
  fi

  # make trafodion tree readable
  sudo chmod -R a+rX $WORKSPACE/home

  # Dev regressions
  if [[ $ret == 0 && -n "$regball" ]]
  then
    echo "*** Installing regressions"
    cd $RUNLOC
    sudo -n -u trafodion tar xf $regball
  fi

  # create alternate directory for Maven Local repo for T2 tests
  if [[ ! -d /var/local/traf_mvn_repo ]]; then
    sudo mkdir /var/local/traf_mvn_repo
  fi
  sudo chown -R trafodion:trafodion /var/local/traf_mvn_repo

  exit $ret

elif [[ $action == "uninstall" ]]
then
  # uninstaller will remove $RUNLOC, so save logs we need
  # see list: traf/files/jenkins_job_builder/config/macros.yaml
  sudo mkdir -p $WORKSPACE/traf_run.save/sql
  sudo cp -r $RUNLOC/logs $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/sql/scripts $WORKSPACE/traf_run.save/sql
  sudo cp -r $RUNLOC/tmp $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/etc $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/dcs* $WORKSPACE/traf_run.save/

  # Same location as install
  cd $INSTLOC 
  echo "Y" | ./installer/trafodion_uninstaller
  uninst_ret=$?

  sudo rm -rf $RUNLOC                   # just in case uninstaller left it
  sudo mv $WORKSPACE/traf_run.save $RUNLOC   # back to the expected location
  sudo chmod -R a+rX $RUNLOC            # make system logs world-readable for archival

  exit $uninst_ret

elif [[ $action == "pyuninstall" ]]
then
  # uninstaller will remove $RUNLOC, so save logs we need
  # see list: traf/files/jenkins_job_builder/config/macros.yaml
  sudo mkdir -p $WORKSPACE/traf_run.save/sql
  sudo cp -r $RUNLOC/logs $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/sql/scripts $WORKSPACE/traf_run.save/sql
  sudo cp -r $RUNLOC/tmp $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/etc $WORKSPACE/traf_run.save/
  sudo cp -r $RUNLOC/dcs* $WORKSPACE/traf_run.save/

  cd $INSTLOC 
  ./python-installer/db_uninstall.py --verbose --silent --config-file ./Install_Config
  uninst_ret=$?

  sudo rm -f $RUNLOC                   # remove symlink
  sudo mv $WORKSPACE/traf_run.save $RUNLOC   # back to the expected location
  sudo chmod -R a+rX $RUNLOC            # make system logs world-readable for archival

  exit $uninst_ret

else
  echo "Error: unsupported action: $action"
  exit 1
fi
