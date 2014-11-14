#!/bin/bash
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2014 Hewlett-Packard Development Company, L.P.
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
log_banner "HBase $1"

action="$1"
jarpath="$2"

if [[ ! "$action" =~ ^start$|^stop$ ]]
then
 echo "Error: first argument must be 'start' or 'stop'."
 exit 1
fi

if [[ "$action" == "start" && -z "$jarpath" ]]
then
   echo "Error: In start mode, jarfile(s) required. Missing argument."
   exit 2
fi

if [[ "$action" == "stop" ]]
then
  echo "Stopping hbase-master"
  # cdh has hbase service, hdp does not
  if [[ -e /etc/init.d/hbase-master ]]
  then
    /sbin/service hbase-master stop
  else
    sudo -u hbase JAVA_HOME=/usr/lib/jvm/java \
	     /usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf stop master
  fi
  echo "Return code $?"
  exit 0
fi

if [[ "$action" == "start" ]]
then
  echo "Make sure zookeeper-server is not running"
  /sbin/service zookeeper-server stop
  echo "Initializing /etc/hbase/conf/hbase-env.sh"
  /bin/cp -f /etc/hbase/conf.dist/hbase-env.sh /etc/hbase/conf.localtest/hbase-env.sh || exit 3
  echo "Adding HBASE_CLASSPATH = $jarpath"
  echo "export HBASE_CLASSPATH=$jarpath" >> /etc/hbase/conf.localtest/hbase-env.sh || exit 3

  echo "Removing/Creating HDFS /hbase"
  set -x
  sudo -u hdfs /usr/bin/hadoop fs -rm -r -f /hbase 
  sudo -u hdfs /usr/bin/hadoop fs -mkdir /hbase
  sudo -u hdfs /usr/bin/hadoop fs -chown hbase:hbase /hbase
  sudo -u hbase rm -rf /var/log/hbase/*
  set +x
  echo "Removing HBase zookeeper data"
  set -x
  sudo rm -rf /tmp/hbase-hbase
  set +x

  echo "Starting hbase-master"
  if [[ -e /etc/init.d/hbase-master ]]
  then
    /sbin/service hbase-master start
  else
    sudo -u hbase JAVA_HOME=/usr/lib/jvm/java \
	     /usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf start master
  fi
  echo "Return code $?"

  exit 0
fi

# should never reach this point
exit 1
