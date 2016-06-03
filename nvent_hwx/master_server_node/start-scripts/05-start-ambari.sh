#!/bin/bash

SETUP_FILE=`basename $0`
SETUP_DIR="/root/.hdp_setup"
if [ ! -f "${SETUP_DIR}/${SETUP_FILE}" ]; then
	sed -i "/^      os.killpg(os.getpgid(pid), signal.SIGKILL)/c\      os.kill(pid, signal.SIGKILL)" /usr/sbin/ambari-server.py
	sed -i "/agent.task.timeout=.+/c\agent.task.timeout=3000" /etc/ambari-server/conf/ambari.properties
	find /var/lib/ambari-server/resources/stacks/ -name metainfo.xml | while read file; do 
		sed -i "/<timeout>.*<\/timeout>/c\<timeout>3000<\/timeout>" $file 
	done
fi

#service httpd start

ambari-server start

while [ `curl -o /dev/null --silent --head --write-out '%{http_code}\n' http://${AMBARI_SERVER}:8080` != 200 ]; do
  sleep 2
done

ambari-agent start

if [ ! -f "${SETUP_DIR}/${SETUP_FILE}" ]; then
	if [ ! -d "${SETUP_DIR}" ]; then
		mkdir -p "${SETUP_DIR}"
	fi
	touch "${SETUP_DIR}/${SETUP_FILE}"
fi
