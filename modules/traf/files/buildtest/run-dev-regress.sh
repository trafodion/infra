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


# Needed for traf-functions.sh
# for case where sudo prevents inheriting environment
WORKSPACE="$1"
shift

source "/usr/local/bin/traf-functions.sh"
log_banner "$*"

SUITES="$*"

set -x

umask 000  # make sure jenkins/trafodion user can read/remove files

# clean up any logs from previous runs
# in case of test time-out we don't want to archive old logs
logarchive="$WORKSPACE/sql-regress-logs"
rundir="$WORKSPACE/rundir"
rm -rf $logarchive $rundir 
mkdir $logarchive

ulimit -c unlimited  # enable core files

# give tests access to build tools (TOOLSDIR)
source_env test

testloc=$(loc_regress)

# run location separate from install location
# since jenkins user does not have write permission to installed loc
mkdir $rundir
export rundir  # pass along to regression tests


# run SQL regression tests
cd $testloc
echo "Saving output in Regress.log"
./tools/runallsb $SUITES 2>&1 | tee  $logarchive/Regress.log | \
   grep --line-buffered -C1 -E '### PASS |### FAIL ' 
echo "Return code ${PIPESTATUS[0]}"

# evaluate tests
cd $rundir

set +x
echo

totalCoreCount=0
missed=0
foundMsg=
for dir in *
do
  if [[ $dir =~ tools|tmp ]]
  then
    rm -rf $dir
    continue
  fi

  echo "========= $dir"
  if [[ -f "$dir/runregr-sb.log" ]]
  then
    cat $dir/runregr-sb.log

    # Any core files means failure
    report_on_corefiles
    coreCount=$?
    totalCoreCount=$(( totalCoreCount + coreCount ))

    if grep -q FAIL "$dir/runregr-sb.log"
    then
      foundMsg="$foundMsg
Found failures -- saving $dir logs to $logarchive/$dir/"
      mkdir $logarchive/$dir
      # Filter out core files
      cp $(ls $dir/* | grep -v "/core.$(hostname)") $logarchive/$dir/
    fi
  else
    echo "Failed -- No tests run for $dir"
    missed=1
  fi
done
echo "========================"
fail=$(grep FAIL */runregr*.log | wc -l)
pass=$(grep PASS */runregr*.log | wc -l)
echo "Total Passed:   $pass"
echo "Total Failures: $fail"

# move aside rundir
# jenkins will upload these logs, in case test times out before we get this far.
# Now that we have gotten this far, we'll only upload the logarchive ones.
cd $WORKSPACE
rm -rf ${rundir}.completed
mkdir ${rundir}.completed
mv ${rundir}/* ${rundir}.completed/

if [[ $totalCoreCount -gt 0 ]]; then
    echo
    echo "Failure : Found $totalCoreCount core files"
fi

if [[ -n "$foundMsg" ]]; then
  echo
  echo "$foundMsg"
fi

if [[ $pass -gt 0 && $fail == 0 && $missed == 0 && $totalCoreCount == 0 ]]
then
  exit 0
else
  exit 5
fi
