#!/bin/bash

SETUP_FILE=`basename $0`
SETUP_DIR="/root/.hdp_setup"
if [ -f "${SETUP_DIR}/${SETUP_FILE}" ]; then
	exit
fi

chkconfig sshd on 
chkconfig ntpd on

OS_VERSION=`cat /etc/redhat-release | /bin/grep -oE '[0-9]+' | head -1`

if [ "${OS_VERSION}" == "6" ]; then
	/etc/init.d/sshd start
	/etc/init.d/ntpd start
	
	echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag
	echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
else
	/bin/systemctl start sshd.service
	/bin/systemctl start ntpd.service
	
	echo never > /sys/kernel/mm/transparent_hugepage/defrag
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

# Replace /etc/hosts file
#umount /etc/hosts
#echo "" >> /root/conf/hosts
#echo "127.0.0.1   localhost" >> /root/conf/hosts
#cp /root/conf/hosts /etc/

# The following link is used by all the Hadoop scripts
rm -rf /usr/java/default
mkdir -p /usr/java/default/bin/
ln -s /usr/bin/java /usr/java/default/bin/java

#Modify ambari-agent configuration to point to ambari server
sed -i "s/hostname=localhost/hostname=$AMBARI_SERVER/g" /etc/ambari-agent/conf/ambari-agent.ini 

if [ ! -d "${SETUP_DIR}" ]; then
	mkdir -p "${SETUP_DIR}"
fi
touch "${SETUP_DIR}/${SETUP_FILE}"