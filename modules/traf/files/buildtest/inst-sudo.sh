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

# install or uninstall
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
  sudo rm -rf $INSTLOC $RUNLOC || exit 1

  sudo mkdir $INSTLOC || exit 1
  sudo mkdir $RUNLOC || exit 1

  sudo chown tinstall $INSTLOC || exit 1

  cp "$instball" $INSTLOC || exit 1

  cd $INSTLOC
  tar xzf $(basename $instball) || exit 1

  # prep ldap config
  sed -e 's/LdapHostname:/LdapHostname:ldap01.trafodion.org/' \
      -e 's/UniqueIdentifier:/UniqueIdentifier:uid=,ou=users,dc=trafldap,dc=com/' \
      ./installer/traf_authentication_conf_default > ./installer/traf_auth_config

  # prep config file  
  cp ./installer/trafodion_config_default ./tc
  echo "NODE_LIST=$(hostname -s)" >> ./tc
  echo "node_count=1" >> ./tc
  echo "LOCAL_WORKDIR=$INSTLOC/installer" >> ./tc
  echo "OPENSTACK_VM=1" >> ./tc
  echo "TRAF_BUILD=$trafball" >> ./tc
  echo "REST_BUILD=$restball" >> ./tc  ## may be empty for pre-1.1 builds
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
  if [[ $LDAP == "true" ]]
  then
    echo "LDAP_SECURITY=Y" >> ./tc
    echo "LDAP_AUTH_FILE=traf_auth_config" >> ./tc
  fi

  check_port 37800
  check_port 40010

  echo "*** Calling trafodion_install"
  ./installer/trafodion_install --accept_license --config_file ./tc
  ret=$?

  check_port 37800
  check_port 40010

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
  sudo chmod -R a+rX $RUNLOC

  exit $ret

elif [[ $action == "uninstall" ]]
then
  # make system logs world-readable for archival
  sudo chmod -R a+rX $RUNLOC

  # Same location as setup
  cd $INSTLOC 
   # try old interface first
  ./installer/trafodion_uninstaller --all --instance $RUNLOC
  if [[ $? != 0 ]]
  then
    # if that fails, try new interface
    echo "Y" | ./installer/trafodion_uninstaller
    exit $?
  else
    exit 0
  fi

else
  echo "Error: unsupported action: $action"
  exit 1
fi
