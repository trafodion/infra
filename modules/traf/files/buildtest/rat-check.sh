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
TMPFILE=/tmp/RatReport.$$

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

rm -f $TEMPFILE

cd "$WORKSPACE"
/usr/bin/java -jar $RATJAR -E ./.rat-exludes -dir . > $TEMPFILE
lic=$(grep -E '^[0-9]+ Unknown Licenses' /tmp/rat24808.out)
if [[ -z "$lic" ]]
then
  echo "Error: RAT report incomplete"
  cat $TEMPFILE
  rm $TEMPFILE
  exit 0  ############# Temporary
fi

count=${lic%% *}

if (( $count > 0 ))
then
  echo "Error: Found $count license issues"
  cat $TEMPFILE
  rm $TEMPFILE
  exit 0  ############# Temporary
else
  echo "Success! Found no license issues."
  rm $TEMPFILE
  exit 0
fi
