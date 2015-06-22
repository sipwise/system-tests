#!/bin/bash

i=1

tmpfile=$(mktemp)
find /etc/ngcp-config/templates/ -type f ! \( -name "*.dpkg-dist" -o -name "*.dpkg-old" -o -name "*.dpkg-new" -o -name "*.dpkg-remove" -o -name "*.dpkg-bak" -o -name "*.dpkg-del" \) -print0 |xargs -0 dpkg -S >/dev/null 2>"$tmpfile"

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
