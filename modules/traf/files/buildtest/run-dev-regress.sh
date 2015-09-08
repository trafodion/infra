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
savedir="$WORKSPACE/rundir.save"
rm -rf $logarchive $rundir $savedir
mkdir $logarchive

ulimit -c unlimited  # enable core files

# give tests access to build tools (TOOLSDIR)
source_env test

testloc=$(loc_regress)

# run location separate from install location
# since jenkins user does not have write permission to installed loc
mkdir $rundir
export rundir  # pass along to regression tests

# Debug for TESTRTS
echo "ABORT_ON_ERROR=8926" >> $MY_SQROOT/etc/ms.env


# run SQL regression tests
cd $testloc
echo "Saving output in Regress.log"
./tools/runallsb $SUITES 2>&1 | tee  $logarchive/Regress.log | \
   grep --line-buffered -C1 -E '### PASS |### FAIL ' | \
   grep --line-buffered -v '^$' | \
   sed --unbuffered -r \
     '-es:(^diff |^cp )(.*/)(.+) (.+):\3:' \
     '-es:(^diff |^cp )(.*/)(.+):\3:' \
     '-es:(^diff |^cp )([a-zA-Z]*[0-9]*)(.*):\2:' \
     '-es:(.*) (DIFF.+*):\2:' \
     '-es:.KNOWN.[a-zA-Z]*::g' \
     '-es:.flt$::' \
     '-es:.OS$::' \
     '-es:\.tmp2$::' \
     '-es:^DIFF:TEST:' \
     '-es:^EXPECTED:TEST:' \
     '-es:^LOG:TEST:' \
     '-es:TESTTEST:TEST:';
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
# move rundir logs aside
# jenkins will upload these logs,
# in case test times out before we get this far.
cd $WORKSPACE
mv $rundir $savedir

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
