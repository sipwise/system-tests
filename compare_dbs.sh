#!/bin/bash

set -euo pipefail

rm -rf results
mkdir results

if ! [[ -r /etc/mysql/sipwise.cnf ]] ; then
  echo "Cannot read mandatory config file /etc/mysql/sipwise.cnf" 2>&1
  exit 1
fi
. /etc/mysql/sipwise.cnf

if ! [[ -r /etc/ngcp-backup-tools/db-backup.conf ]] ; then
  NGCP_DB_BACKUP_FINAL_LIST=(accounting billing carrier fileshare kamailio ldap ngcp prosody provisioning rtcengine stats)
fi
. /etc/ngcp-backup-tools/db-backup.conf

for db in "${NGCP_DB_BACKUP_FINAL_LIST[@]}" ; do
  compare_dbs.pl --result="result_${db}.tap" \
  --connect_db1="DBI:mysql:database=${db};host=db01a" \
  --user_db1='sipwise' --pass_db1="${SIPWISE_DB_PASSWORD}" \
  --connect_db2="DBI:mysql:database=${db};host=db01b" \
  --user_db2='sipwise' --pass_db2="${SIPWISE_DB_PASSWORD}"
done
