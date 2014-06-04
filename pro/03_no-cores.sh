#!/bin/bash
SYSCTL="/sbin/sysctl"
CORE_DIR=$(dirname $(${SYSCTL} kernel.core_pattern | awk '{print $3}'| sed -e "s_'__g"))
NUM_FILES=$(ls -1 ${CORE_DIR}|wc -l)

echo "1..1"

if [ -d ${CORE_DIR} ]; then
	if [[ $NUM_FILES > 0 ]]; then
		echo "not ok ${CORE_DIR} not empty"
	else
		echo "ok ${CORE_DIR} empty"
	fi
else
	echo "ok no ${CORE_DIR}"
fi
