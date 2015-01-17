#!/bin/bash
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
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# @@@ END COPYRIGHT @@@

SCRIPT_NAME=`basename $0`
DASHBOARD_DIR="/usr/share/puppet-dashboard"
DASHBOARD_LOCK="/usr/share/puppet-dashboard/tmp/pids/purge-dashboard.lock"

# file lock to ensure only one is running at any given time
exec 7>$DASHBOARD_LOCK
if flock -n 7
then
    pid=$$
    echo $pid 1>&7

    # clean up dashboard database
    cd $DASHBOARD_DIR
    # remove reports
    sudo -u www-data rake RAILS_ENV=production reports:prune upto=4 unit=wk 2> \
      >(grep -vE '^(NOTE: )?Gem.*|^config\.gem: Unpacked' >&2)
    # remove orphans
    sudo -u www-data rake RAILS_ENV=production reports:prune:orphaned 2> \
      >(grep -vE '^(NOTE: )?Gem.*|^config\.gem: Unpacked' >&2)
    # optimize database
    sudo -u www-data rake RAILS_ENV=production db:raw:optimize 2> \
      >(grep -vE '^(NOTE: )?Gem.*|^config\.gem: Unpacked' >&2)
else
    echo "Cannot acquire file lock. Script $SCRIPT_NAME is already running on pid " `cat $DASHBOARD_LOCK`
    exit 1
fi
