#!/bin/sh 

set -x

sqstop
echo "Return code $?"
sudo /usr/local/bin/hbase-sudo.sh stop
echo "Return code $?"

