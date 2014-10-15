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

# install or uninstall
action="$1"

# work location - required for traf-functions.sh
WORKSPACE="$2"

# required tarballs for install
instball="$3"
trafball="$4"
dcsball="$5"
# optional sql regression tarball
regball="$6"

source "/usr/local/bin/traf-functions.sh"
log_banner "Trafodion $action"

set -x

if [[ $action == "install" ]]
then
  # first clean out hbase from previous tests
  sudo /usr/local/bin/hbase-clean.sh

  sudo rm -rf $INSTLOC $RUNLOC || exit 1

  sudo mkdir $INSTLOC || exit 1
  sudo mkdir $RUNLOC || exit 1

  sudo chown tinstall $INSTLOC || exit 1

  cp "$instball" $INSTLOC || exit 1

  cd $INSTLOC
  tar xzf $(basename $instball) || exit 1

  echo "accept" | 
     ./installer/trafodion_setup --nodes "localhost"  || exit 2

  ./installer/trafodion_mods --trafodion_build "$trafball" || exit 2

  # trafodion user should exist after setup
  sudo chown trafodion $RUNLOC || exit 1

  sudo -n -i -u trafodion ./trafodion_installer --dcs_servers 6 --init_trafodion \
	       --build "$trafball" \
	       --dcs_build "$dcsball" \
	       --install_path $RUNLOC
  ret=$?
  if [[ $ret == 0 && -n "$regball" ]]
  then
    cd $RUNLOC
    tar xf $regball
  fi
  exit $ret

elif [[ $action == "uninstall" ]]
then
  cd $INSTLOC

  sudo -n -i -u trafodion ./trafodion_uninstall \
                --instance $RUNLOC
  exit $?

else
  echo "Error: unsupported action: $action"
  exit 1
fi
