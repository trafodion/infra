#!/bin/sh

# file lock to run only one at a time.
# Remove files after 2 weeks.
# Remove empty directories after a day.
sleep $((RANDOM%600)) && \
find -O3 /srv/static/downloads/trafodion/publish/daily/ -depth \
    \( \
         \( -type f -mtime +14 -execdir rm \{\} \; \) \
      -o \( -type d -not -name lost+found -empty -mtime +1 \
          -execdir rmdir {} \; \) \
    \)
