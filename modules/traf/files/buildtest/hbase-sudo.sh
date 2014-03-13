#!/bin/bash

action="$1"
jarpath="$2"

if [[ ! "$action" =~ ^start$|^stop$ ]]
then
 echo "Error: first argument must be 'start' or 'stop'."
 exit 1
fi

if [[ "$action" == "start" && ! -f "$jarpath" ]]
then
 echo "Error: In start mode, jarfile required. No such file: $jarpath"
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
  echo "Initializing /etc/hbase/conf/hbase-env.sh"
  /bin/cp -f /etc/hbase/conf.dist/hbase-env.sh /etc/hbase/conf.localtest/hbase-env.sh || exit 3
  echo "Adding HBASE_CLASSPATH = $jarpath"
  echo "export HBASE_CLASSPATH=$jarpath" >> /etc/hbase/conf.localtest/hbase-env.sh || exit 3

  echo "Starting hbase-master"
  /sbin/service hbase-master start
  echo "Return code $?"

  exit 0
fi

# should never reach this point
exit 1

