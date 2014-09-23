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

# Check if Cloudera-Manager or Ambari is installed
USE_INSTALLER=0

for pkg in cloudera-manager-server ambari-server
do
  rpm -q $pkg >/dev/null
  if [[ $? == 0 ]]
  then
    USE_INSTALLER=1
  fi
done

# No hadoop management SW, just stop trafodion in place
if [[ $USE_INSTALLER == 0 ]]
then
  /usr/local/bin/stop-traf-instance.sh "$@"
  exit $?
fi

# Use trafodion uninstaller

set -x

# tinstall user has required permissions 
sudo -n -u tinstall /usr/local/bin/inst-sudo.sh uninstall
exit $?
