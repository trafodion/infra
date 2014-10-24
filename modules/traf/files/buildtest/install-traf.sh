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

source "/usr/local/bin/traf-functions.sh"
log_banner

# Option to install regression tests
if [[ "$1" == "sqlregress" ]]
then
  REGRESS="regress"
  shift
else
  REGRESS=""
fi

rm -rf $WORKSPACE/hbase-logs

# if we have tinstall user defined, we are
# configured for trafodion installer
if id tinstall 2>/dev/null
then
  USE_INSTALLER=1
else
  USE_INSTALLER=0
fi

# No hadoop management SW, just start trafodion in place
if [[ $USE_INSTALLER == 0 ]]
then
  # record instance location - build tree
  install_loc "build" $REGRESS

  echo "Saving output in Install_Start.log"
  set -x
  /usr/local/bin/start-traf-instance.sh "$@" 2>&1 | tee Install_Start.log | \
       grep --line-buffered -e '^\+'
  ret=${PIPESTATUS[0]}
  if [[ $ret == 0 ]]
  then
    set +x
  
    echo "INFO: Waiting a minute to check for DcsServer"
    sleep 60
  
    set -x
    if [ $(jps | grep -c DcsServer) -ne $NUM_DCS ]; then
      echo "ERROR: No DcsServer found. Please check your DCS setup."
      exit 1
    fi
    echo ""
    exit 0
  else
    exit $ret
  fi

fi

# Use trafodion installer

# record instance location - install location
install_loc "installed" $REGRESS

# Core, DCS, Install are all required

trafball="$(/bin/ls $WORKSPACE/trafodion/core/trafodion_server-*.tgz)"
dcsball="$(/bin/ls $WORKSPACE/trafodion/dcs/target/dcs*gz)"
instball="$(/bin/ls $WORKSPACE/trafodion/install/installer*gz)"

flist="$instball $trafball $dcsball"
if [[ $REGRESS == "regress" ]]
then
  regball="$(/bin/ls $WORKSPACE/trafodion/core/trafodion-regress.tgz)"
  flist+=" $regball"
fi

for f in $flist
do
  if [[ ! -f $f ]]
  then
    echo "Error: File not found: $f"
    exit 1
  fi
done

echo "Saving output in Install_Start.log"
set -x

# make sure tinstall user can read them
chmod o+r $flist

# tinstall user has required permissions to run installer
sudo -n -u tinstall /usr/local/bin/inst-sudo.sh install "$WORKSPACE" \
       "$instball" \
       "$trafball" \
       "$dcsball" \
       "$regball" 2>&1 | tee Install_Start.log | \
          grep --line-buffered -e '\*\*\*'
exit ${PIPESTATUS[0]}
