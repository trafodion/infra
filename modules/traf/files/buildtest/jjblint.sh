#!/bin/bash
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

rc=0     #so far, so good
found=0  # no JJB files found
TMPFILE=/tmp/JJBCheckFileList.$$
listcmd="git show --pretty=format:%n --name-status HEAD"

echo "INFO: File list command: $listcmd"
$listcmd > $TMPFILE

while read fStatus fName
do
  if [[ -n "$fName" ]]; then
    if [[ "$fStatus" != "D" ]] && [[ "$fName" =~ ^.*\/jenkins_job_builder\/config\/.*$ ]]; then
      found=1
      echo "INFO: Testing Jenkins Job config file $fName ..."
      if [[ "${fName##*/}" != "defaults.yaml" ]] || [[ "${fName##*/}" != "macros.yaml" ]]; then
        /usr/local/bin/jenkins-jobs test ${fName%/*}/macros.yaml $fName
      else
        /usr/local/bin/jenkins-jobs test $fName
      fi
      rc=$?
    fi
  fi
done < $TMPFILE

if [[ $found -eq 0 ]]; then echo "INFO: No Jenkins Job config files needed linting."; fi

rm -f $TMPFILE

exit $rc
