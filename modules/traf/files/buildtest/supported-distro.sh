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


# Determine which hadoop distros are supported by given trafodion code

if [[ -z "$1" ]]
then
  echo "Error: path to source tree required"
  exit 1
fi

DIR="$1"

features="$DIR/core/sqf/conf/install_features"

rm -rf distro.properties

if [[ ! -f $features ]]
then
  echo "Error: $features file not found"
  exit 1
fi

source $features

if [[ $CDH_5_3_HDP_2_2_SUPPORT == "Y" ]]
then
  echo "DISTCDH = 5.3" > distro.properties
  echo "DISTHDP = 2.2" >> distro.properties
elif [[ $CDH_5_4_SUPPORT == "Y" ]]
then
  echo "DISTCDH = 5.4" >> distro.properties
fi
if [[ $HDP_2_3_SUPPORT == "Y" ]]
then
  echo "DISTHDP = 2.3" >> distro.properties
fi

if [[ ! -f distro.properties ]]
then
  echo "Error: Found no supported distros"
  exit 1
fi

exit 0