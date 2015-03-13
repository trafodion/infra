#!/bin/bash

# Req: need root (sudo) permission to check key disk usage (du)

echo "Check Node ==============="
D=$(date)

purpose="${D}:  $BUILD_TAG"  # jenkins build identifier

# disk free space on root filesys?
root_space=$(/bin/df -h / 2>/dev/null | sed "s/^/$D:  /")

echo "Root FS space"
echo "$root_space"
echo "$purpose" >> ~jenkins/dspace-root.log
echo "$root_space" >> ~jenkins/dspace-root.log

# disk usage of suspect locations
check="/hadoop/hdfs /var/log"

select_usage=$(sudo /usr/bin/du -sh $check  2>/dev/null | sed "s/^/$D:  /")

echo "Disk usage of specific directories"
echo "$select_usage"
echo "$purpose" >> ~jenkins/dusage.log
echo "$select_usage" >> ~jenkins/dusage.log

# check in hdfs space?

exit 0  # we don't want any job failing due to this check
