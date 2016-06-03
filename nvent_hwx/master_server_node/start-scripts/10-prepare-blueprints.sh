#!/bin/bash

SETUP_FILE=`basename $0`
SETUP_DIR="/root/.hdp_setup"
if [ -f "${SETUP_DIR}/${SETUP_FILE}" ]; then
	exit
fi

#Wait a bit to ensure that Ambari server is fully up and running
sleep 20 

/root/scripts/install_cluster.sh $BLUEPRINT_BASE

if [ ! -d "${SETUP_DIR}" ]; then
	mkdir -p "${SETUP_DIR}"
fi
touch "${SETUP_DIR}/${SETUP_FILE}"