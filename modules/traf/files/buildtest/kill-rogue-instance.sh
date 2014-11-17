#!/bin/sh
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
log_banner

if id trafodion >/dev/null 2>&1
then
  user="trafodion"
else
  user="jenkins"
fi

# output key instance process IDs
function trafprocs() {
  if [[ $user == "trafodion" ]]
  then
    sudo -n -u trafodion /usr/bin/jps | grep DcsMaster | cut -f1 -d' '
  else
    jps | grep DcsMaster | cut -f1 -d' '
  fi
  pgrep -u $user -f 'mpirun|monitor|sqwatchdog|mxosrvr|jetty|sqlci|sql/scripts'
}

# Look for the usual suspects
Instance=$(trafprocs)

if [[ -z "$Instance" ]]
then
  exit 0
fi

echo "Found running instance. Attempting to kill it"

attempt=1

while [[ $attempt -lt 6 ]]
do
  ps -u $user -H
  if [[ $user == "trafodion" ]]
  then
    sudo -n -u trafodion kill -9 $Instance
  else
    kill -9 $Instance
  fi
  sleep 3

  Instance=$(trafprocs)
  if [[ -z "$Instance" ]]
  then
    echo "Post-kill processes:"
    ps -u $user -H
    exit 0
  fi
  (( attempt += 1 ))
done

echo "Some instance processes still hanging around:"
ps -u $user -H
exit 1
