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

source "/usr/local/bin/traf-functions.sh"
log_banner

# Option to configure LDAP
if [[ "$1" == "--ldap" ]]
then
  LDAP="$1"
  shift
else
  LDAP=""
fi

# Option to install regression tests
if [[ "$1" == "sqlregress" ]]
then
  REGRESS="regress"
  shift
else
  REGRESS=""
fi

COREDIR="$1"

# DCS arguments are optional when not using installer
DCSDIR="$2"
DCSSERV="$3"

# check to see if clients should be installed
if [[ "$4" == "installdrivers" ]]
then
  log_banner "Installing Trafodion clients to $WORKSPACE/clients"
  cd $WORKSPACE
  rm -rf clients
  tar xvfz $(ls $WORKSPACE/trafodion/core/trafodion_clients-*.tgz $WORKSPACE/trafodion/distribution/*trafodion_clients* 2>/dev/null)
  cd clients

  # install JDBC T4 client
  log_banner "Installing Trafodion JDBC T4 Driver"
  if [[ -e JDBCT4.zip ]]
  then
    mkdir jdbc
    cd jdbc
    unzip ../JDBCT4.zip
    zrc=$?
  else
    unzip jdbcT4*.zip
    zrc=$?
  fi
  if [[ $zrc -ne 0 ]]
  then
    echo "ERROR: Could not unzip JDBC T4 driver"
    exit 1
  fi

  # install ODBC client
  log_banner "Installing Trafodion ODBC Driver"
  cd $WORKSPACE/clients
  tar xvfz TRAF_ODBC_Linux_Driver_64.tar.gz
  echo ""
  cd PkgTmp
  ./install.sh <<-END_ODBC 2>&1 | tee $WORKSPACE/Traf_Odbc_Install.log | grep --line-buffered -A 4 -e '^TRAFODBC driver'
YES
$WORKSPACE/clients/odbc
$WORKSPACE/clients/odbc
$WORKSPACE/clients/odbc
$WORKSPACE/clients/odbc
END_ODBC

  if [[ ${PIPESTATUS[0]} -ne 0 ]]
  then
    echo "ERROR: Could not install Trafodion ODBC Driver"
    exit 1
  fi

  # install trafci client
  log_banner "Installing Trafodion Command Interface"
  cd $WORKSPACE/clients
  jpath=$(/bin/ls $WORKSPACE/clients/jdbc*/lib/jdbcT4*.jar)
  unzip trafci.zip trafciInstaller.jar
  java -jar trafciInstaller.jar cm <<-END_TRAFCI 2>&1 | tee $WORKSPACE/Trafci_Install.log
Y
$jpath
$WORKSPACE/clients
N
END_TRAFCI

  if [[ ${PIPESTATUS[0]} -ne 0 ]]
  then
    echo "ERROR: Could not install Trafodion Command Interface"
    exit 1
  fi
fi

cd $WORKSPACE

rm -rf $WORKSPACE/hbase-logs

log_banner "Setting up Trafodion"


# DCS is not optional
#   default to 4 servers
if [[ ! $DCSSERV =~ [0-9]+ ]]
then
  DCSSERV=4
fi

# record instance location - install location
install_loc "installed" $REGRESS

# Core, DCS, Install are all required

trafball="$(/bin/ls $WORKSPACE/trafodion/core/trafodion_server-*.tgz $WORKSPACE/trafodion/distribution/*trafodion_server-* 2>/dev/null)"
dcsball="$(/bin/ls $WORKSPACE/trafodion/dcs/target/dcs*gz $WORKSPACE/trafodion/distribution/dcs-[0-9]*gz 2>/dev/null)"
instball="$(/bin/ls $WORKSPACE/trafodion/install/installer*gz $WORKSPACE/trafodion/distribution/*_installer*gz 2>/dev/null)"
pyinstball="$(/bin/ls $WORKSPACE/trafodion/distribution/*pyinstaller*gz 2>/dev/null)"
restball="$(/bin/ls $WORKSPACE/trafodion/core/rest/target/rest-*gz $WORKSPACE/trafodion/distribution/rest-*gz 2>/dev/null)"

# py installer supercedes bash installer
  # Currently only on release2.1 branch
  if [[ -n $ghprbTargetBranch ]]
  then
    relbranch="$ghprbTargetBranch"
  elif [[ -n $GIT_BRANCH ]]
  then
    relbranch="$GIT_BRANCH"
  else 
    relbranch="$BRANCH"
  fi
if [[ -n $pyinstball && $relbranch ]]
then
  action=pyinstall
  instball=$pyinstball
  filter='^.'
else
  action=install
  filter='\*\*\*'
fi

flist="$instball $trafball"
if [[ $REGRESS == "regress" ]]
then
  regball="$(/bin/ls $WORKSPACE/trafodion/core/trafodion-regress.tgz $WORKSPACE/trafodion/distribution/*trafodion-regress.tgz 2>/dev/null)"
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

# JDK path different on RH6/7
if [[ "$(lsb_release -rs | cut -d. -f1)" == "6" ]]
then
  JDKPKG="openjdk.x86_64"
else
  JDKPKG="openjdk"
fi

# default java home
JH="/usr/lib/jvm/java-1.7.0-$JDKPKG"

features=$WORKSPACE/trafodion/core/sqf/conf/install_features
if [[ -r $features ]]
then
  echo "Source $features"
  source $features
  if [[ $JAVA_8_SUPPORT == "Y" ]]
  then
    JH="/usr/lib/jvm/java-1.8.0-$JDKPKG"
  fi
fi
echo "Java for Trafodion install: $JH"

echo "Saving output in Install_Start.log"
set -x

# make sure tinstall user can read them
chmod o+r $flist

echo "Checking shared mem"
ls -ld /dev/shm
ls -l /dev/shm
echo "============"

# tinstall user has required permissions to run installer
sudo -n -u tinstall /usr/local/bin/inst-sudo.sh $LDAP $action "$WORKSPACE" \
       "$instball" \
       "$trafball" \
       "$restball" \
       "$dcsball" "$DCSSERV" \
       "$regball" "$JH" 2>&1 | tee Install_Start.log | \
          grep --line-buffered -e "$filter"
ret=${PIPESTATUS[0]}

# Check mxosrvr processes match requested DCS servers
if [[ $ret == 0 ]]
then
  count=$(pgrep -u trafodion ^mxosrvr | wc -l)
  time=0
  while (( $count < $DCSSERV && $time < 120 ))
  do
    sleep 10
    (( time+=10 ))
    count=$(pgrep -u trafodion ^mxosrvr | wc -l)
  done
  if (( $count < $DCSSERV ))
  then
    echo "Error: requested mxo server processes did not come up"
    exit 3
  fi
fi
exit $ret
