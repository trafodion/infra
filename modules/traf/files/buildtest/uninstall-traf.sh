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

source /usr/local/bin/traf-functions.sh
log_banner

# if we have tinstall user defined, we are
# configured for trafodion installer
if id tinstall 2>/dev/null
then
  USE_INSTALLER=1
else
  USE_INSTALLER=0
fi

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
