#!/bin/bash
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

#===================
# Define variables
#===================
export PRG_NAME=`basename $0`

# functions
PROGRAM_HELP() {
set +x
    echo "
    Usage: $PRG_NAME <Trafodion_PATH> [<DCS_PATH> <Num_DCS_Servers>]

    Options :
        <Trafodion_PATH>        Location where Trafodion is is installed
        <DCS_PATH>              Location where DCS is installed
        <Num_DCS_Servers>       Number of DCS servers to configure
                                NOTE: This parameter must be specified if <DCS_PATH> is specified

    NOTE: If relative PATHS are used for <Trafodion_PATH> and <DCS_PATH>, make sure the relative paths
          are specified from the same starting directory.

    Examples :
        $PRG_NAME "trafodion/core"              # starts only trafodion using relative paths
        $PRG_NAME "/home/trafodion/core"        # starts only trafodion using absolute paths
        $PRG_NAME "trafodion/core" "trafodion/dcs" "6"  # configures/starts 6 DCS servers and starts trafodion
        $PRG_NAME "/home/trafodion/core" "/home/trafodion/dcs" "6"  # configures/starts 6 DCS servers and starts trafodion

"
set -x
}


CONFIGURE_DCS() {
    # install DCS from target build
    set -x
    pkg=$(ls $WORKSPACE/$DCS_DIR/target/dcs*gz)
    rm -rf $WORKSPACE/dcs || exit 1
    mkdir -p $WORKSPACE/dcs
    cd $WORKSPACE/dcs || exit 1
    tar xf $pkg || exit 1
    installdir=$(ls -d $WORKSPACE/dcs/*)

    # configure traf environemnt to point to dcs we just unpackaged
    cd $WORKSPACE/$TRAF_DIR/sqf || exit 1
    modify_env "export DCS_INSTALL_DIR=\"$installdir\""
    set +x

    echo ""
    echo "INFO: Setting up DCS to NOT manage zookeeper"

    set -x
    # configure DCS to NOT manage zookeeper
    cd "$installdir" || exit 1
    if [ $(grep -v '#' conf/dcs-env.sh | grep -c 'DCS_MANAGES_ZK=false') -eq 0 ]; then
        sed -i".bak" -e 's/# export DCS_MANAGES_ZK=.*/export DCS_MANAGES_ZK=false/' conf/dcs-env.sh
    fi
    set +x

    echo ""
    echo "INFO: Contents of conf/dcs-env.sh"
    cat conf/dcs-env.sh

    echo ""
    echo "INFO: Configure IP address and DNS interface in conf/dcs-site.xml"

    set -x
    # configure ip address of zookeeper and dns interface
    if [ $(grep -c 'zookeeper.quorum' conf/dcs-site.xml) -eq 0 ]; then
        sed -i".bak" 's@</configuration>@@' conf/dcs-site.xml
	cat - >>conf/dcs-site.xml <<-EOF
	  <property>
	    <name>dcs.zookeeper.quorum</name>
	    <value>localhost</value>
	  </property>
	  <property>
	    <name>dcs.dns.interface</name>
	    <value>eth0</value>
	  </property>
	</configuration>
	EOF
    fi
    set +x

    echo ""
    echo "INFO: Configure a total of $DCS_NUM_SERVERS DCS servers"

    set -x
    cat /dev/null > conf/servers            # zero out the conf/servers file
    for ((i=1; i<=DCS_NUM_SERVERS; i++)) {
        echo "localhost" >> conf/servers
    }
    set +x

    echo ""
    echo "INFO: Contents of conf/servers"
    cat conf/servers
    echo ""
}

START_TRAF() {
    set -x
    cd $WORKSPACE
    sudo /usr/local/bin/hbase-sudo.sh stop
    echo "Return code $?"

    # make sure our workspace is readable by hbase user
    chmod -R a+rX $TRAF_DIR

    # start up instance
    cd $TRAF_DIR/sqf
    mkdir -p ./etc
    cp -f /etc/SQSystemDefaults.conf ./etc/

    # system hadoop installation location
    export HADOOP_MAPRED_HOME=/usr/lib/hadoop-mapreduce

    source_env run

    # Check jar files
    jarpath=""
    for jar in "${HBASE_TRXDIR}/${HBASE_TRX_JAR}"
    do
      if [[ ! -f "$jar" ]]
      then
        echo "Warning: File not found: $jar"
      else
        [[ -z $jarpath ]] && jarpath="$jar" || jarpath="${jarpath}:$jar"
      fi
    done

    # set java path and start HBase
    sudo /usr/local/bin/hbase-sudo.sh start "$jarpath"
    echo "Return code $?"

    # generate new schema
    sqgen
    echo "Return code $?"

    sqstart
    echo "Return code $?"

    sqps

    sqcheck || exit 1


    # initialize meta-data
    echo 'initialize trafodion; exit;' | sqlci > init_trafodion.log 2>&1
    # Look for error other than 1392 - "already initialized"
    grep -v 1392 init_trafodion.log | grep -q ERROR
    if [[ $? == 0 ]]; then
        echo "Initialize Trafodion failed."
        cat init_trafodion.log
        sqstop
        exit 2
    fi
}

# main
set -x
clear_env

if [ $# -eq 1 ]; then
    export TRAF_DIR="$1"
elif [ $# -eq 3 ]; then
    export TRAF_DIR="$1"
    export DCS_DIR="$2"
    export DCS_NUM_SERVERS="$3"

    CONFIGURE_DCS
else
    echo "ERROR: Incorrect number of input parameters passed to ${PRG_NAME}"
    PROGRAM_HELP
    exit 1
fi

START_TRAF

exit 0

