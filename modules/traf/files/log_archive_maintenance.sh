#!/bin/sh

# file lock to run only one at a time.
# Compress files after 3 days, remove compressed files after 2 weeks.
# Remove empty directories after a day.
ulimit -n 150000
sleep $((RANDOM%600)) && \
find /srv/static/logs/ -depth \
    \( \
      \( -type f -mtime +3 -not -name robots.txt \
          -not -wholename /srv/static/logs/help/\* \
          -not -wholename /srv/static/logs/buildvers/\* \
          -not -wholename /srv/static/logs/winbld/\* \
          -not -wholename /srv/static/logs/testdeps/\* \
          -not -name \*\[.-\]gz -not -name \*\[._-\]\[zZ\] \
          -exec gzip -f \{\} \; \) \
      -o \( -type f -mtime +14 -name \*.gz -execdir rm \{\} \; \) \
      -o \( -type d -not -name lost+found -empty -mtime +1 \
          -execdir rmdir {} \; \) \
    \)
