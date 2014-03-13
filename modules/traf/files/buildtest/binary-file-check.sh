#!/bin/bash 

rc=0   #so far, so good

text_pat='ASCII|UTF-|empty|very short file (no magic)|cannot open|text'
image_pat='image|icon'
size_limit=80000  #image file limit in bytes

listcmd="git show --pretty=format:%n --name-only HEAD"

echo "File list command: $listcmd"
echo "'file' command reports:"
$listcmd | while read fName
do
  if [ -n "$fName" ]; then
    ftype=$(file -b $fName)
    echo "$fName : $ftype"

    # Image file
    if [[ "$ftype" =~ $image_pat ]]
    then
      fsize=$(stat -c %s $fName)
      if [[ $fsize -gt $size_limit ]]
      then
        echo "  ERROR: Image file size $fsize bytes greater than $size_limit"
	rc=1
      else
        echo "  Image file size $fsize bytes okay"
      fi
    elif [[ "$ftype" =~ $text_pat ]]
    then
      echo "  Empty/Text file okay"
    else
      echo "  ERROR: Unknown file type not allowed"
      rc=1
    fi
  fi
done 


exit $rc
