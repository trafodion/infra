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

# Search source files for known bad strings

source /usr/local/bin/traf-functions.sh
log_banner

rc=0   #so far, so good

egrepcmd="egrep -r -n -e'<<<<<<<.*HEAD|>>>>>>>>.*HEAD'"
echo "Search command: $egrepcmd"
echo

# Find lines ignoring this script
LINESSEEN=$(eval $egrepcmd * 2>/dev/null | grep -v $(basename $0) | wc -l)
if [[ $LINESSEEN -gt 0 ]]; then
  FILESSEEN=$(eval $egrepcmd * 2>/dev/null | grep -v $(basename $0) | cut -f1 -d: | sort -u)
  FILESCOUNT=$(echo $FILESSEEN | wc -w)
  echo "ERROR: Found string(s) which should not be in source code, in $LINESSEEN lines(s) in $FILESCOUNT file(s)."
  echo
  echo "Files ="
  echo $FILESSEEN | fmt -w1
  echo
  echo "Lines with context are:"
  echo
  eval $egrepcmd -C 4 * 2>/dev/null
  rc=1
else
  echo "Success! Found no bad lines."
fi

exit $rc
