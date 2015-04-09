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

source /usr/local/bin/traf-functions.sh
log_banner

# output key instance process IDs
function trafprocs() {
  sudo -n -u "$s_user" /usr/bin/jps | grep -E 'Dcs|TrafodionRest' | cut -f1 -d' '
  pgrep -u "$p_user" -f 'SQMON|mpirun|monitor|sqwatchdog|mxosrvr|jetty|sqlci|sql/scripts|pstack|pstartd|gdb'
}

# identify user ID of trafodion processes
function trafuid() {
  # look for processes unique to trafodion
  orphan_pid=$(pgrep -f 'mpirun|SQMON|mxosrvr|traf_run' | head -1)
  if [[ ! -z $orphan_pid ]]
  then 
    ghost_user=$(ps -o uid --pid $orphan_pid | tail -1)
  else
    ghost_user=NONE
  fi
  echo $ghost_user
}

function check_port() {
  portnum=$1
  # ss will let us know if port is in use, and -p option will give us process info
  # (must be root to get info if we don't own the process)
  cmd="/usr/sbin/ss -lp src *:$portnum"

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
}


if id trafodion >/dev/null 2>&1
then
  p_user="trafodion" # ps, pgrep
  s_user="trafodion" # sudo
else
  p_user=$(trafuid)
  s_user="#$p_user" # special syntax for numeric ID
fi

if [[ $p_user != "NONE" ]]
then
    # Look for the usual suspects
    Instance=$(trafprocs)
fi

if [[ -z "$Instance" ]]
then
  echo "Found no trafodion processes"
  check_port 37800  # check DCS
  check_port 40010
  exit 0
fi

echo "Found running instance. Attempting to kill it"

# Now that instance always run as trafodion user, we
# can just kill every processes owned by that user id
# When it was jenkins user, that was not possible.

attempt=1
set -x
while [[ $attempt -lt 10 ]]
do
  ps -u $p_user -H
  pkill -9 -u $p_user
  sleep 4

  Instance=$(trafprocs)
  if [[ -z "$Instance" ]]
  then
    echo "Post-kill processes:"
    ps -u $p_user -H
    check_port 37800
    check_port 40010
    exit 0
  fi
  (( attempt += 1 ))
done

echo "Some instance processes still hanging around:"
ps -u $p_user -H

# Check usage of DCS port (default 37800)
check_port 37800
check_port 40010

exit 1
