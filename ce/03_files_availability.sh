#!/bin/bash

i=1
declare -a FILES=( "/etc/ngcp_version" \
                   "/etc/sipwise_ngcp_version" \
                   "/etc/apt/sources.list.d/sipwise.list" \
                   "/etc/ngcp-config/config.yml" \
                   "/etc/ngcp-config/constants.yml" \
                   "/etc/ngcp-config/network.yml" \
                 )

echo "1..$(( 2 *${#FILES[@]} ))"

for FILE in "${FILES[@]}" ; do

  if [ -f ${FILE} ]; then
    echo "ok $i - Found file: ${FILE}"
  else
    echo "not ok $i - File not found: ${FILE}"
  fi
  i=$(($i+1))

  COUNT=$(stat -c%s ${FILE} 2>/dev/null || echo 0)
  if [ "$COUNT" != "0" ]; then
    echo "ok $i - File is not empty: ${FILE}"
  else
    echo "not ok $i - File is empty: ${FILE}"
  fi
  i=$(($i+1))

done
