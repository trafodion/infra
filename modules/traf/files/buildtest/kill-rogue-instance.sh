#!/bin/sh 

# Look for the usual suspects
# might need to get more agressive
Instance=$(pgrep -u jenkins -f 'mpirun|monitor|sqwatchdog|mxosrvr|jetty|sqlci')

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
