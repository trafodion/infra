#!/bin/sh
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

# Publish/Stage builds only for daily builds
# 

# directory tree to save
DIR="$1"
SAVE="${DIR}.SAVED"

# remove previous save
rm -rf "$SAVE"

cd "$DIR"
# replicate directories
find . -type d | while read d ; do mkdir -p "$SAVE/$d" ; done
# hard-link files
find . -type f | while read f ; do ln "$f" "$SAVE/$f"; done
# copy symlinks
find . -type l | while read l ; do cp -d "$l" "$SAVE/$l"; done



exit 0
