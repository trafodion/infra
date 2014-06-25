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

# Look for the usual suspects
# might need to get more agressive
Instance=$(pgrep -u jenkins -f 'mpirun|monitor|sqwatchdog|mxosrvr|jetty|sqlci|sql/scripts')

if [[ -z "$Instance" ]]
then
  exit 0
fi

echo "Found running instance. Attempting to kill it"

attempt=1

while [[ $attempt -lt 6 ]]
do
  ps -u jenkins -H
  kill -9 $Instance
  sleep 3

  Instance=$(pgrep -u jenkins -f 'mpirun|monitor|sqwatchdog|mxosrvr|jetty')
  if [[ -z "$Instance" ]]
  then
    echo "Post-kill processes:"
    ps -u jenkins -H
    exit 0
  fi
  (( attempt += 1 ))
done

echo "Some instance processes still hanging around:"
ps -u jenkins -H
exit 1
