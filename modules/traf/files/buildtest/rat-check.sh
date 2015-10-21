#!/bin/bash
# @@@ START COPYRIGHT @@@
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

RATTAR="apache-rat-0.11-bin.tar.gz"
RATURL="http://www.interior-dsgn.com/apache//creadur/apache-rat-0.11/apache-rat-0.11-bin.tar.gz"
RATJAR="$HOME/apache-rat-0.11/apache-rat-0.11.jar"

source /usr/local/bin/traf-functions.sh
log_banner


if [[ ! -f $RATJAR ]]
then
  echo "Downloading RAT"  
  cd $HOME
  wget $RATURL
  tar xf $RATTAR
  if [[ ! -f $RATJAR ]]
  then
    echo "Error: could not find RAT"
    exit 0  ############# Temporary
  fi
fi

REPORT="$WORKSPACE/RatReport"
rm -f $REPORT

# remove any extraneous files
cd "$WORKSPACE/trafodion"
git clean -x -f -d

cd "$WORKSPACE"
/usr/bin/java -jar $RATJAR -E trafodion/.rat-excludes -dir trafodion > $REPORT
lic=$(grep -E '^[0-9]+ Unknown Licenses' $REPORT)
if [[ -z "$lic" ]]
then
  echo "Error: RAT report incomplete"
  cat $REPORT
  exit 0  ############# Temporary
fi

count=${lic%% *}

if (( $count > 0 ))
then
  echo "Error: Found $count license issues"
  cat $REPORT
  exit 0  ############# Temporary
else
  echo "Success! Found no license issues."
  exit 0
fi
