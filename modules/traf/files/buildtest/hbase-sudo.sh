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
  /sbin/service hbase-master stop
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

  echo "Starting hbase-master"
  /sbin/service hbase-master start
  echo "Return code $?"
  # Work around hbase-trx bug
  sleep 15
  if [[ -d /var/hbase/hbase/recovered.edits ]]
  then
    echo "WARNING: found /var/hbase/hbase/recovered.edits directory (LP 1290610). Deleting..."
    rmdir /var/hbase/hbase/recovered.edits || exit 2
  fi

  exit 0
fi

# should never reach this point
exit 1
