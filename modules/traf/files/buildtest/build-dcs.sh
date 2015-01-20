#!/bin/sh
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2015 Hewlett-Packard Development Company, L.P.
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

set -x

#DCS source location, relative to workspace
SRCDIR=$1

#optional parameter for JDBC driver location
# core build tree, relative to workspace
COREDIR="$2"

export JAVA_HOME="/usr/lib/jvm/java-1.7.0-openjdk.x86_64"

if [[ -n "$COREDIR" ]]
then
  BLD="$(< $WORKSPACE/Build_ID)"
  mvn install:install-file -Dfile=$WORKSPACE/$COREDIR/conn/jdbc_type4/lib/jdbcT4.jar \
	-DgroupId=org.trafodion.jdbc.t4.T4Driver -DartifactId=t4driver -Dversion="$BLD" \
	-Dpackaging=jar -DgeneratePom=true
  JDBCVER="-Djdbct4.version=$BLD"
else
  JDBCVER=""  # use default specified in pom.xml
fi


cd $SRCDIR

mvn -B $JDBCVER clean site package install
rc=$?

cd $WORKSPACE

exit $rc
