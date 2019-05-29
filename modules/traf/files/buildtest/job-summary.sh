#!/bin/bash

# Summarize results of all child jobs in format suitable for email

BUILD_URL="$1"

if [[ -z "$BUILD_URL" ]]
then
  echo "Error: Missing jenkins environment variable BUILD_URL"
  exit 1
fi

rm -f build_result.json
rm -f build_result.txt

curl -s -k $BUILD_URL/api/json > build_result.json

blds=$(jq -r '.subBuilds|length' < build_result.json)

# subBuild object sample:
#  "url": "job/core-regress-seabase-ahw2.2/70/",
#  "retry": false,
#  "result": "SUCCESS",
#  "abort": false,
#  "buildNumber": 70,
#  "duration": "1 hr 16 min",
#  "icon": "blue.png",
#  "jobName": "core-regress-seabase-ahw2.2",
#  "parentBuildNumber": 22,
#  "parentJobName": "Check-Daily",
#  "phaseName": "build_test"

i=0
while (( $i < $blds ))
do
  jq -r ".subBuilds[$i]|.url,.result,.duration,.jobName" < build_result.json | {
    read url
    read result
    read duration
    read job

    curl -s -k $JENKINS_URL/$url/logText/progressiveText | grep -v grep | grep -q 'WARNING: Core files found'
    if [[ $? == 0 ]]
    then
      cf=" *Corefiles*"
    else
      cf=""
    fi
    
    echo -n $result
    echo -n " $job"
    echo -n " ($duration)"
    echo -n "$cf"
    echo
  } 
  (( i += 1 ))
done  | sort > build_result.txt
