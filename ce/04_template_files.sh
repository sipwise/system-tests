#!/bin/bash

i=1

tmpfile=$(mktemp)
find /etc/ngcp-config/templates/ -type f -print0 |xargs -0 dpkg -S >/dev/null 2>"$tmpfile"

if ! [ -s "$tmpfile" ] ; then
  echo "1..1"
  echo "ok 1 - no unpackaged files in /etc/ngcp-config/templates/"
else
  echo "1..$(wc -l < "${tmpfile}")"
  while read line ; do
    echo "not ok $i - $line"
    i=$(( i+1 ))
  done < "${tmpfile}"
fi

rm -f "$tmpfile"
