#!/bin/bash

SCRIPT_NAME=`basename $0`
DASHBOARD_LOCK="/usr/share/puppet-dashboard/tmp/pids/purge-dashboard.lock"

# file lock to ensure only one is running at any given time
exec 7>$DASHBOARD_LOCK
if flock -n 7
then
    pid=$$
    echo $pid 1>&7

    # clean up dashboard database
    cd $DASHBOARD_DIR
    sudo -u www-data rake RAILS_ENV=production reports:prune upto=4 unit=wk     # remove reports
    sudo -u www-data rake RAILS_ENV=production reports:prune:orphaned           # remove orphans
    sudo -u www-data rake RAILS_ENV=production db:raw:optimize                  # optimize database
else
    echo "Cannot acquire file lock. Script $SCRIPT_NAME is already running on pid " `cat $DASHBOARD_LOCK`
    exit 1
fi
