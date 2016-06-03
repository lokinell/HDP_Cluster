#!/bin/sh

# Get Args Passed in Regarding Repo Information
for arg_item in "$@"
do
	if echo "${arg_item}" | grep "="; then
		value=`echo "${arg_item}" | cut -d= -f2`
	fi
	if [[ ${arg_item} == HOST_IP=* ]]; then
		HOST_IP=${value}
	fi
	if [[ ${arg_item} == AMBARI_VERSION=* ]]; then
		AMBARI_VERSION=${value}
	fi
	if [[ ${arg_item} == AMBARI_REPO=* ]]; then
		AMBARI_REPO=${value}
	fi
	if [[ ${arg_item} == HDP_VERSION=* ]]; then
		HDP_VERSION=${value}
	fi
	if [[ ${arg_item} == HDP_REPO=* ]]; then
		HDP_REPO=${value}
	fi
	if [[ ${arg_item} == HDP_UTILS_VERSION=* ]]; then
		HDP_UTILS_VERSION=${value}
	fi
	if [[ ${arg_item} == HDP_UTILS_REPO=* ]]; then
		HDP_UTILS_REPO=${value}
	fi
	if [[ ${arg_item} == BLUEPRINT=* ]]; then
		BLUEPRINT=${value}
	fi
	if [[ ${arg_item} == ADDITIONAL_DATANODES=* ]]; then
		ADDITIONAL_DATANODES=${value}
	fi
	if [[ ${arg_item} == OS_EXTRAS_REPO=* ]]; then
		OS_EXTRAS_REPO=${value}
	fi
	if [[ ${arg_item} == JDK=* ]]; then
		JDK=${value}
	fi
	if [[ ${arg_item} == JCE=* ]]; then
		JCE=${value}
	fi
	if [[ ${arg_item} == JAVA_INSTALL_PATH=* ]]; then
		JAVA_INSTALL_PATH=${value}
	fi
	
done

OS_VERSION=`cat /etc/redhat-release | /bin/grep -oE '[0-9]+' | head -1`

echo
echo "OS_VERSION=${OS_VERSION}"
echo "HOST_IP=${HOST_IP}"
echo "AMBARI_VERSION=${AMBARI_VERSION}"
echo "AMBARI_REPO=${AMBARI_REPO}"
echo "HDP_VERSION=${HDP_VERSION}"
echo "HDP_REPO=${HDP_REPO}"
echo "HDP_UTILS_VERSION=${HDP_UTILS_VERSION}"
echo "HDP_UTILS_REPO=${HDP_UTILS_REPO}"
HDP_MINOR=`echo ${HDP_VERSION} | cut -d. -f1-2`
echo "HDP_MINOR=${HDP_MINOR}"
echo "BLUEPRINT=${BLUEPRINT}"
echo "ADDITIONAL_DATANODES=${ADDITIONAL_DATANODES}"
echo "OS_EXTRAS_REPO=${OS_EXTRAS_REPO}"
echo "JDK=${JDK}"
echo "JCE=${JCE}"
echo "JAVA_INSTALL_PATH=${JAVA_INSTALL_PATH}"
echo
echo "Update /etc/resolv.conf"
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo
echo "Validating OS Release for Ambari, HDP, and HDP-UTILS."
echo "Adjusting if necessary."

AMBARI_REPO=`echo "${AMBARI_REPO}" | sed "s/centos./centos${OS_VERSION}/g;"`
HDP_REPO=`echo "${HDP_REPO}" | sed "s/centos./centos${OS_VERSION}/g;"`
HDP_UTILS_REPO=`echo "${HDP_UTILS_REPO}" | sed "s/centos./centos${OS_VERSION}/g;"`

echo "AMBARI_REPO=${AMBARI_REPO}"
echo "HDP_REPO=${HDP_REPO}"
echo "HDP_UTILS_REPO=${HDP_UTILS_REPO}"
echo

echo "Install unzip telnet perl"
yum -y install unzip telnet perl

# Check if /repos was created for the local repos
if [ -d "/repos" ]; then
	echo "Install httpd for Local Repo"
	yum -y install httpd
	/usr/bin/perl -p -i -e "s/^DocumentRoot.+/DocumentRoot \"\/repos\"/g;" /etc/httpd/conf/httpd.conf
	/usr/bin/perl -p -i -e "s/^<Directory \"\/var\/www\/html\">/<Directory \"\/repos\">/g;" /etc/httpd/conf/httpd.conf

	echo "Start Local Repo Web Server"
	chkconfig httpd on
	service httpd start

	if [ "${OS_EXTRAS_REPO}" != "" ]; then
		echo "Create Local Repo"
		cat > /etc/yum.repos.d/${OS_EXTRAS_REPO}.repo <<EOF
[${OS_EXTRAS_REPO}]
name=${OS_EXTRAS_REPO}
baseurl=http://${HOST_IP}/${OS_EXTRAS_REPO}/
gpgcheck=0
enabled=1
priority=1
EOF
	fi
fi

echo "Update System Files"
/usr/bin/perl -p -i -e "s/^(net.ipv4.ip_forward =).+/\$1 1/g;" /etc/sysctl.conf
/usr/bin/perl -p -i -e "s/^SELINUX=.+/SELINUX=disabled/g;" /etc/selinux/config

echo "Add /data disk"
yum -y install xfsprogs

if [ ! -d /data ]; then
  if [ -e /dev/sdb ]; then
    mkdir /data
    chmod 777 /data
    mkfs -t xfs /dev/sdb
    FSTAB=`cat /etc/fstab | grep "/data"`
    if [ -z "$FSTAB" ]; then
      echo "/dev/sdb /data xfs     defaults        0 0" >> /etc/fstab
    fi
    mount /dev/sdb /data
  fi
fi

echo "Install Docker Compose"
yum -y install epel-release
yum -y install python-pip
pip install --upgrade pip
pip install docker-compose
pip install backports.ssl_match_hostname --upgrade

echo "Restart Docker"
if [ "${OS_VERSION}" == "6" ]; then
	service docker stop
	chkconfig docker on
else
	/bin/systemctl stop  docker.service
	/bin/systemctl enable docker.service
fi

# Move /var/lib/docker/volumes to additional external /data disk
if [ ! -d /data/docker ]; then
  mkdir -p /data/docker
	chmod -R 700 /data/docker
	if [ -d /var/lib/docker/volumes ]; then
	  mv /var/lib/docker/volumes /data/docker/
	  ln -s /data/docker/volumes/ /var/lib/docker/volumes
	fi
fi

if [ "${OS_VERSION}" == "6" ]; then
	service docker start
else
	/bin/systemctl start docker.service
fi

echo "Download Nvent HWX Docker Images"
cd /data
if [ -d /vagrant/nvent_hwx ]; then
	if [ ! -d /data/nvent_hwx ]; then
		cp -r /vagrant/nvent_hwx /data
	fi
fi

if [ ! -f /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.blueprint ]; then
  echo "Create Blueprint"	

	cp /vagrant/blueprints/${BLUEPRINT}* /data/nvent_hwx/master_server_node/blueprints
	
	# Set Stack Version in the Blueprints File
	/usr/bin/perl -p -i -e "s/\"stack_version\" : \"(.+)\"/\"stack_version\" : \"${HDP_MINOR}\"/g;" /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.blueprint

	
	# If the HDP is >= 2.4.2.0 then we need to add the METRICS_GRAFANA Component if it
	# doesn't exist. Will be added to the same node as the namenode's METRICS_MONITOR
	# since we have port 3000 assigned to this node. We also assume this is the first
	# node defined in the Blueprint
	if [ "${HDP_VERSION}" \> "2.4.1" ]; then
		if ! $(grep -q "METRICS_GRAFANA" "/data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.blueprint"); then
#			/usr/bin/perl -p -i -e "s/^(\s+)(\"name\" : \"METRICS_MONITOR\")/\$1\$2\n                \},\n                \{\n\$1\"name\" : \"METRICS_GRAFANA\"/;" /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.blueprint
			/usr/bin/perl -p -i -e '$a=1 if (!$a && s/^(\s+)("name" : "METRICS_MONITOR")/$1$2\n                \},\n                \{\n$1"name" : "METRICS_GRAFANA"/g);' /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.blueprint

		fi
	fi
	if [ ! -f /vagrant/blueprints/${BLUEPRINT}.hostmapping ]; then
		cat > /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.hostmapping <<EOF
{
  "blueprint":"${BLUEPRINT}",
  "default_password":"admin",
  "host_groups":[
    { 
      "name":"namenode",
      "hosts":[ { "fqdn":"namenode" } ] 
    },
    {
      "name":"resourcemanager",
      "hosts":[ { "fqdn":"resourcemanager" } ]
    },
    {
      "name":"hiveserver",
      "hosts":[ { "fqdn":"hiveserver" } ]
EOF
		if [ "${ADDITIONAL_DATANODES}" == "0" ]; then
			cat >> /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.hostmapping <<EOF
    }
  ]
}
EOF
		else
			WORKER_LIST=""
			for ((i=1;i<=${ADDITIONAL_DATANODES};i++));
			do
				if [ "${WORKER_LIST}" == "" ]; then
					WORKER_LIST="{\"fqdn\":\"node${i}\"}"
				else
					WORKER_LIST="${WORKER_LIST}, {\"fqdn\":\"node${i}\"}"
				fi
			done
			cat >> /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}.hostmapping <<EOF
    },
    {
      "name":"worker",
      "hosts":[ ${WORKER_LIST} ]
    }
  ]
}
EOF
		fi
	fi

	chmod 644 /data/nvent_hwx/master_server_node/blueprints/${BLUEPRINT}*
fi

# Setup Passwordless SSH from the Docker server to all the nodes using the
# same Key as the Ambari Server
if [ ! -d /root/.ssh ]; then
	mkdir /root/.ssh
fi

if [ ! -d /root/.ssh/id_rsa ]; then
	cp /data/nvent_hwx/base_node/conf/id_rsa /root/.ssh/id_rsa
	cp /data/nvent_hwx/base_node/conf/id_rsa.pub /root/.ssh/id_rsa.pub
	chmod -R 600 /root/.ssh/
fi


##########################################################################################
#
# NVENT_HWX/BASE_NODE
#
##########################################################################################

if ! docker images | grep "nvent_hwx/base_node"; then
	echo "Creating NVENT_HWX/BASE_NODE Docker Container"
	cd /data/nvent_hwx/base_node

	# Set the base image to CentOS 6 or 7 as needed. This is based on the major version
	# in the host OS in /etc/redhat-release
	/usr/bin/perl -p -i -e "s/^FROM centos.*/FROM centos:centos${OS_VERSION}/g;" /data/nvent_hwx/base_node/Dockerfile

	# Add the -e environment variables to the startup.sh script since
	# systemctl will not read the Docker environment variables
	if [ "${OS_VERSION}" == "7" ]; then


		/usr/bin/perl -p -i -e "s/^(#!\/bin\/bash)/\$1\n\n\. \/etc\/bashrc\nexport TERM=xterm\nexport AMBARI_SERVER=namenode\nexport BLUEPRINT_BASE=${BLUEPRINT}\nexport namenode_ip=\`grep namenode \/etc\/hosts \| cut -d\" \" -f1 \| head -1\`\n/g;" /data/nvent_hwx/base_node/scripts/startup.sh
	fi

	# Handle a local repo file to install files from an alternate source. Repo directory
	# should be in the /repos location with the same name
	if [ "${OS_EXTRAS_REPO}" != "" ]; then
		cp /etc/yum.repos.d/${OS_EXTRAS_REPO}.repo /data/nvent_hwx/base_node/conf
		/usr/bin/perl -p -i -e "s/(COPY conf\/ambari.repo.+)/\$1\nCOPY conf\/${OS_EXTRAS_REPO}.repo \/etc\/yum.repos.d\/${OS_EXTRAS_REPO}.repo\n/g;" /data/nvent_hwx/base_node/Dockerfile
	fi

	if [[ "${JDK}" == http* ]]; then
		DOWNLOAD_JDK="wget -q --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' ${JDK}"
	else
		DOWNLOAD_JDK="wget -q http://${HOST_IP}/${OS_EXTRAS_REPO}/${JDK}"
	fi
	if [[ "${JCE}" == http* ]]; then
		DOWNLOAD_JCE="wget -q --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' ${JCE}"
	else
		DOWNLOAD_JCE="wget -q http://${HOST_IP}/${OS_EXTRAS_REPO}/${JCE}"
	fi

	cat > /data/nvent_hwx/base_node/scripts/installJDK.sh <<EOF
#!/bin/sh
mkdir /root/JDK
cd /root/JDK
${DOWNLOAD_JDK}
${DOWNLOAD_JCE}

if [ ! -d `dirname ${JAVA_INSTALL_PATH}` ]; then
	mkdir `dirname ${JAVA_INSTALL_PATH}`
fi
tar xfz /root/JDK/`basename ${JDK}` -C `dirname ${JAVA_INSTALL_PATH}`
unzip -o -j /root/JDK/jce_policy-8.zip -d ${JAVA_INSTALL_PATH}/jre/lib/security/
cd /root
/bin/rm -rf /root/JDK
EOF

	chmod 755 /data/nvent_hwx/base_node/scripts/installJDK.sh
	tmp_path=`echo ${JAVA_INSTALL_PATH} | sed 's/\//\\\\\//g'`

	/usr/bin/perl -p -i -e "s/JAVA_HOME=[^\"]+/\JAVA_HOME=${tmp_path}/g;" /data/nvent_hwx/base_node/Dockerfile
	/usr/bin/perl -p -i -e "s/export PATH=\/usr\/jdk64\/jdk1.8.0_60/export PATH=${tmp_path}/g;" /data/nvent_hwx/base_node/Dockerfile

	if [ "${AMBARI_VERSION}" != "" -a "${AMBARI_REPO}" != "" ]; then
		tmp_repo_path=`echo ${AMBARI_REPO} | sed 's/\//\\\\\//g'`

		if [[ "${AMBARI_REPO}" == http* ]]; then
			/usr/bin/perl -p -i -e "s/^RUN wget http:.+\/ambari.repo -O \/etc\/yum.repos.d\/ambari.repo/RUN wget ${tmp_repo_path} -O \/etc\/yum.repos.d\/ambari.repo/g;" /data/nvent_hwx/base_node/Dockerfile
		else
			/usr/bin/perl -p -i -e "s/^(RUN wget .+)/#\$1/g;" /data/nvent_hwx/base_node/Dockerfile
			/usr/bin/perl -p -i -e "s/^#(COPY conf\/ambari.repo.+)/\$1/g;" /data/nvent_hwx/base_node/Dockerfile
		
			/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/base_node/conf/ambari.repo
			/usr/bin/perl -p -i -e "s/<AMBARI_VERSION>/${AMBARI_VERSION}/g;" /data/nvent_hwx/base_node/conf/ambari.repo
			/usr/bin/perl -p -i -e "s/<AMBARI_REPO>/${tmp_repo_path}/g;" /data/nvent_hwx/base_node/conf/ambari.repo
		fi
	
		# Replace any <LOCAL_REPO> keywords with HOST_IP
		/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/base_node/conf/*.repo
		/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/base_node/scripts/*
	fi
	
	if [ "${OS_VERSION}" == "7" ]; then
		/usr/bin/perl -p -i -e "s/^ENTRYPOINT/#ENTRYPOINT/g;" /data/nvent_hwx/base_node/Dockerfile

		cat >> /data/nvent_hwx/base_node/Dockerfile <<EOF
	
# Systemctl Support for CentOS 7
RUN yum clean all && yum install -y initscripts # for old "service"

RUN yum -y install systemd*; yum clean all; \\
(cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ \$i == systemd-tmpfiles-setup.service ] || rm -f \$i; done); \\
rm -f /lib/systemd/system/multi-user.target.wants/*; \\
rm -f /etc/systemd/system/*.wants/*; \\
rm -f /lib/systemd/system/local-fs.target.wants/*; \\
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \\
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \\
rm -f /lib/systemd/system/basic.target.wants/*; \\
rm -f /lib/systemd/system/anaconda.target.wants/*;

COPY scripts/centos7_hdp.service /etc/systemd/system/
RUN systemctl enable centos7_hdp.service
VOLUME [ "/sys/fs/cgroup" ]
#CMD ["/usr/sbin/init"]
ENTRYPOINT ["/usr/sbin/init"]
EOF
	fi
	docker build -t nvent_hwx/base_node .
	if [ $? -ne 0 ]; then
		echo "Failed to build docker container nvent_hwx/base_node"
		exit 1
	fi
fi


##########################################################################################
#
# NVENT_HWX/MASTER_SERVER_NODE
#
##########################################################################################

if ! docker images | grep "nvent_hwx/master_server_node"; then
	echo "Creating NVENT_HWX/MASTER_SERVER_NODE Docker Container"
	cd /data/nvent_hwx/master_server_node


	/usr/bin/perl -p -i -e "s/versions\/(.+)\/operating_systems/versions\/${HDP_MINOR}\/operating_systems/g;" /data/nvent_hwx/master_server_node/scripts/install_cluster.sh
	/usr/bin/perl -p -i -e "s/repositories\/HDP-[^ ]+(.+)hdp.repo/repositories\/HDP-${HDP_MINOR}\$1hdp.repo/g;" /data/nvent_hwx/master_server_node/scripts/install_cluster.sh
	/usr/bin/perl -p -i -e "s/redhat[^\/]+\//redhat${OS_VERSION}\//g;" /data/nvent_hwx/master_server_node/scripts/install_cluster.sh
	/usr/bin/perl -p -i -e "s/repositories\/HDP-UTILS-[^ ]+(.+)hdputils.repo/repositories\/HDP-UTILS-${HDP_UTILS_VERSION}\$1hdputils.repo/g;" /data/nvent_hwx/master_server_node/scripts/install_cluster.sh

	tmp_path=`echo ${JAVA_INSTALL_PATH} | sed 's/\//\\\\\//g'`
	/usr/bin/perl -p -i -e "s/^RUN ambari-server setup.+/RUN ambari-server setup -s -j ${tmp_path}/g;" /data/nvent_hwx/master_server_node/Dockerfile

	if [ "${OS_VERSION}" == "7" ]; then
		# Comment out ambari-server setup in the Dockerfile.
		# Can't start a service during docker build phase under systemctl
		/usr/bin/perl -p -i -e "s/^RUN ambari-server setup/#RUN ambari-server setup/g;" /data/nvent_hwx/master_server_node/Dockerfile
#		/usr/bin/perl -p -i -e "s/^ambari\-/nohup ambari\-/g;" /data/nvent_hwx/master_server_node/start-scripts/05-start-ambari.sh
		/usr/bin/perl -p -i -e "s/^(ambari\-[^ ]+)\s+(.+)/systemctl \$2 \$1/g;" /data/nvent_hwx/master_server_node/start-scripts/05-start-ambari.sh

		# Create startup script to configure ambari-server
		cat > /data/nvent_hwx/master_server_node/start-scripts/04-configure-ambari-server.sh <<EOF
#!/bin/sh

SETUP_FILE=\`basename \$0\`
SETUP_DIR="/root/.hdp_setup"
if [ -f "\${SETUP_DIR}/\${SETUP_FILE}" ]; then
  exit
fi

ambari-server setup -s -j ${JAVA_INSTALL_PATH}
ambari-server stop

if [ ! -d "\${SETUP_DIR}" ]; then
  mkdir -p "\${SETUP_DIR}"
fi
touch "\${SETUP_DIR}/\${SETUP_FILE}"

EOF
	fi
	chmod 755 /data/nvent_hwx/master_server_node/start-scripts/04-configure-ambari-server.sh
	
	if [ "${HDP_VERSION}" != "" -a "${HDP_REPO}" != "" ]; then
		tmp_repo_path=`echo ${HDP_REPO} | sed 's/\//\\\\\//g'`

		if [[ "${HDP_REPO}" == http* ]]; then
			/usr/bin/perl -p -i -e "s/RUN wget .+ -O \/etc\/yum.repos.d\/HDP.repo/RUN wget ${tmp_repo_path} -O \/etc\/yum.repos.d\/HDP.repo/g;" /data/nvent_hwx/master_server_node/Dockerfile
			t_repo=`dirname ${HDP_REPO}`
			repo_path=`echo ${t_repo} | sed 's/\//\\\\\//g'`

		else
			/usr/bin/perl -p -i -e "s/^#COPY conf\/HDP\.repo/COPY conf\/HDP\.repo/g;" /data/nvent_hwx/master_server_node/Dockerfile
			/usr/bin/perl -p -i -e "s/^RUN wget/#RUN wget/g;" /data/nvent_hwx/master_server_node/Dockerfile

			/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/master_server_node/repos/*.repo
			/usr/bin/perl -p -i -e "s/<HDP_REPO>/${tmp_repo_path}/g;" /data/nvent_hwx/master_server_node/repos/*.repo
			/usr/bin/perl -p -i -e "s/<HDP_VERSION>/${HDP_VERSION}/g;" /data/nvent_hwx/master_server_node/repos/*.repo

			/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			/usr/bin/perl -p -i -e "s/<HDP_REPO>/${tmp_repo_path}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			/usr/bin/perl -p -i -e "s/<HDP_VERSION>/${HDP_VERSION}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			repo_path=`echo http://${HOST_IP}/${HDP_REPO} | sed 's/\//\\\\\//g'`
		fi
		/usr/bin/perl -p -i -e "s/^.+\"base_url\"\:.+/    \"base_url\"\: \"${repo_path}\",/g;" /data/nvent_hwx/master_server_node/repos/hdp.repo
	fi

	# Only needed if we are using a local repo as it is included in the HDP.repo
	if [ "${HDP_UTILS_VERSION}" != "" -a "${HDP_UTILS_REPO}" != "" ]; then
		if [[ "${HDP_UTILS_REPO}" == http* ]]; then
			repo_path=`echo ${HDP_UTILS_REPO} | sed 's/\//\\\\\//g'`
		else
			/usr/bin/perl -p -i -e "s/<LOCAL_REPO>/${HOST_IP}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			tmp_repo_path=`echo ${HDP_UTILS_REPO} | sed 's/\//\\\\\//g'`
			/usr/bin/perl -p -i -e "s/<HDP_UTILS_REPO>/${tmp_repo_path}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			/usr/bin/perl -p -i -e "s/<HDP_UTILS_VERSION>/${HDP_UTILS_VERSION}/g;" /data/nvent_hwx/master_server_node/conf/*.repo
			repo_path=`echo http://${HOST_IP}/${HDP_UTILS_REPO} | sed 's/\//\\\\\//g'`
			/usr/bin/perl -p -i -e "s/^(COPY conf\/HDP.repo.+)/\$1\nCOPY conf\/HDP-UTILS.repo \/etc\/yum.repos.d\/HDP-UTILS.repo/g;" /data/nvent_hwx/master_server_node/Dockerfile
		fi
		/usr/bin/perl -p -i -e "s/^.+\"base_url\"\:.+/    \"base_url\"\: \"${repo_path}\",/g;" /data/nvent_hwx/master_server_node/repos/hdputils.repo
	fi
	
	if [ "${OS_VERSION}" == "7" ]; then
		/usr/bin/perl -p -i -e "s/^ENTRYPOINT/#ENTRYPOINT/g;" /data/nvent_hwx/master_server_node/Dockerfile
	fi
		
	docker build -t nvent_hwx/master_server_node .
	if [ $? -ne 0 ]; then
		echo "Failed to build docker container nvent_hwx/master_server_node"
		exit 1
	fi
fi


##########################################################################################
#
# NVENT_HWX/AGENT_NODE
#
##########################################################################################

if ! docker images | grep "nvent_hwx/agent_node"; then
	echo "Creating NVENT_HWX/AGENT_NODE Docker Container"
	cd /data/nvent_hwx/agent_node

	if [ "${OS_VERSION}" == "7" ]; then
		/usr/bin/perl -p -i -e "s/^ENTRYPOINT/#ENTRYPOINT/g;" /data/nvent_hwx/agent_node/Dockerfile
#		/usr/bin/perl -p -i -e "s/^ambari\-/nohup ambari\-/g;" /data/nvent_hwx/agent_node/start-scripts/05-start-ambari.sh
		/usr/bin/perl -p -i -e "s/^(ambari\-[^ ]+)\s+(.+)/systemctl \$2 \$1/g;" /data/nvent_hwx/agent_node/start-scripts/05-start-ambari.sh

	fi

	docker build -t nvent_hwx/agent_node .
	if [ $? -ne 0 ]; then
		echo "Failed to build docker container nvent_hwx/agent_node"
		exit 1
	fi
fi

##########################################################################################


if [ "${OS_VERSION}" == "6" ]; then
	service docker restart
else
	/bin/systemctl restart  docker.service
fi

cd /data/nvent_hwx

# Needed for systemctl for CentOS 7 and Docker (container=docker is in Dockerfile)
if [ "${OS_VERSION}" == "7" ]; then
	/usr/bin/perl -p -i -e "s/--dns/-v \/tmp\/\\\$\(mktemp -d\):\/run -v \/sys\/fs\/cgroup:\/sys\/fs\/cgroup --dns/g;" /data/nvent_hwx/nvent_multi_node.sh
fi
/data/nvent_hwx/nvent_multi_node.sh "${ADDITIONAL_DATANODES}" "${BLUEPRINT}" | tee /data/nvent_hwx/nvent_multi_node.log




# docker exec -it namenode /bin/bash
#docker rmi -f $(docker images | grep '^<none>' | awk '{print $3}')