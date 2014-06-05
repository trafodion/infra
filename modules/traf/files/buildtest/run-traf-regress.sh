#!/bin/sh

source "/usr/local/bin/traf-functions.sh"

DIR="$1"  # build tree
shift
SUITES="$*"

workspace="$(pwd)"

set -x

# clean up any logs from previous runs
# in case of test time-out we don't want to archive old logs
logarchive="$workspace/sql-regress-logs"
rm -rf $logarchive
mkdir $logarchive

/usr/local/bin/start-traf-instance.sh "$DIR" || exit 1

cd $DIR/sqf
source_env

# run SQL regression tests
cd ../sql/regress
echo "Saving output in Regress.log"
./tools/runallsb $SUITES 2>&1 | tee  $logarchive/Regress.log | \
   sed  --unbuffered    -r -es':(^diff |^cp )([a-zA-Z]*[0-9]*)(.*):\2:' | \
   grep --line-buffered -C1 -E '### PASS |### FAIL '
echo "Return code ${PIPESTATUS[0]}"

/usr/local/bin/stop-traf-instance.sh

# evaluate tests
cd ../../sqf/rundir

set +x

missed=0
for dir in *
do
  if [[ $dir =~ tools|tmp ]]
  then
    continue
  fi

  echo "========= $dir"
  if [[ -f "$dir/runregr-sb.log" ]]
  then
    cat $dir/runregr-sb.log
    if grep -q FAIL "$dir/runregr-sb.log"
    then
      echo "Found failures -- saving $dir logs."
      mkdir $logarchive/$dir
      cp $dir/* $logarchive/$dir/
    fi
  else
    echo "Failed -- No tests run"
    missed=1
  fi
done
echo "========================"
fail=$(grep FAIL */runregr*.log | wc -l)
pass=$(grep PASS */runregr*.log | wc -l)
echo "Total Passed:   $pass"
echo "Total Failures: $fail"

if [[ $pass > 0 && $fail == 0 && $missed == 0 ]]
then
  exit 0
else
  exit 5
fi
