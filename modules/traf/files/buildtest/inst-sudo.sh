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

if [[ $action == "pyinstall" ]]
then
  sudo yum clean all # clean stale data
  sudo sed -i 's/\(mirrorlist=http\)s/\1/' /etc/yum.repos.d/epel.repo # use http access

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
  echo "traf_log = $WORKSPACE/home/trafodion/traf_run/logs" >> ./Install_Config
  echo "traf_var = $WORKSPACE/home/trafodion/traf_run/tmp" >> ./Install_Config
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
