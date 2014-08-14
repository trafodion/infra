#!/bin/bash

# run as user hdfs

# uses tpcds tool (in current dir) to generate data and load into HDFS
# assumes dependencies are satisfied as per tpcds.pp

TEMP_DATA_DIR=/tmp/tpcds

set -o errexit  # bail out on any error

rm -rf $TEMP_DATA_DIR

mkdir $TEMP_DATA_DIR

echo "Generating the data..." 

TABLES="date_dim time_dim item customer customer_demographics household_demographics customer_address store promotion store_sales"

for t in $TABLES
do
  ./dsdgen -force Y -dir $TEMP_DATA_DIR -scale 1 -table $t
done


echo "Copying generated data to HDFS..."
for t in $TABLES
do
  # rmr (on hadoop 1.2) exits with error if path does not exist
  #/usr/bin/hadoop fs -rmr /hive/tpcds/$t
  # hadoop 1: mkdir does not allow -p, just assumes it
  # hadoop 2: mkdir needs -p for multiple dir levels, so lets try both
  /usr/bin/hadoop fs -mkdir /hive/tpcds/$t || /usr/bin/hadoop fs -mkdir -p /hive/tpcds/$t
  /usr/bin/hadoop fs -put $TEMP_DATA_DIR/${t}.dat /hive/tpcds/$t
done

/usr/bin/hadoop fs -ls /hive/tpcds/*/*.dat

rm -rf $TEMP_DATA_DIR
