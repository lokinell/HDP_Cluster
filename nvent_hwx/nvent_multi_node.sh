#!/bin/bash

if [ $# -lt 1 ]
then
  echo "Number of worker nodes not specified - using a default of 4"
  NUM_WORKERS="4" 
else
  NUM_WORKERS=$1
fi

export BLUEPRINT_BASE=$2
: ${BLUEPRINT_BASE:="multinode"}


# This function will list all ip of running containers
function listip {
	echo "127.0.0.1	localhost"
	for vm in `docker ps|tail -n +2|awk '{print $NF}'`; 
		do
			ip=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $vm`;
			echo "$ip  $vm";
		done    
}

# This function will copy hosts file to all running container /etc/hosts
function updateip {
	for vm in `docker ps|tail -n +2|awk '{print $NF}'`;
		do
			echo "copy hosts file to  $vm";
			copied=NO
			while [ "${copied}" == "NO" ]; do
				docker exec -i $vm sh -c 'cat > /etc/hosts' < /tmp/hosts
				if [ $? -eq 0 ]; then
					copied=YES
				fi
			done
		done
}





# Create startup/shutdown scripts
HWX_LOGS=/root/nvent_hwx_logs
if [ ! -d /root/nvent_hwx_logs ]; then
	mkdir $HWX_LOGS
fi

if [ ! -f /root/start_cluster.sh ]; then
	echo '#!/bin/sh' > /root/start_cluster.sh
	echo -n 'docker start namenode resourcemanager hiveserver' >> /root/start_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/start_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/start_cluster.sh

#	echo "$0 \"${NUM_WORKERS}\" \"${BLUEPRINT_BASE}\"" >> /root/start_cluster.sh
	
	chmod 755 /root/start_cluster.sh
fi

if [ ! -f /root/stop_cluster.sh ]; then
	echo '#!/bin/sh' > /root/stop_cluster.sh
	echo -n 'docker stop namenode resourcemanager hiveserver' >> /root/stop_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/stop_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/stop_cluster.sh
	chmod 755 /root/stop_cluster.sh
fi

if [ ! -f /root/restart_cluster.sh ]; then
	echo '#!/bin/sh' > /root/restart_cluster.sh
	echo -n 'docker stop namenode resourcemanager hiveserver' >> /root/restart_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/restart_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/restart_cluster.sh

	echo -n 'docker start namenode resourcemanager hiveserver' >> /root/restart_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/restart_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/restart_cluster.sh
	
	chmod 755 /root/restart_cluster.sh
fi


if [ ! -f /root/destroy_cluster.sh ]; then
	echo '#!/bin/sh' > /root/destroy_cluster.sh
	echo -n 'docker stop namenode resourcemanager hiveserver' >> /root/destroy_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/destroy_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/destroy_cluster.sh
	echo -n 'docker rm namenode resourcemanager hiveserver' >> /root/destroy_cluster.sh
	for (( i=1; i<=$NUM_WORKERS; ++i));
	do
		echo -n " node$i" >> /root/destroy_cluster.sh
	done
	echo " | tee ${HWX_LOGS}/docker.log" >> /root/destroy_cluster.sh
	
	chmod 755 /root/destroy_cluster.sh
fi

if [ "${NUM_WORKERS}" -gt 0 ]; then
	if [ ! -f /root/restart_datanodes.sh ]; then
		echo '#!/bin/sh' > /root/restart_datanodes.sh
		echo -n 'docker stop' >> /root/restart_datanodes.sh
		for (( i=1; i<=$NUM_WORKERS; ++i));
		do
			echo -n " node$i" >> /root/restart_datanodes.sh
		done
		echo " | tee ${HWX_LOGS}/docker.log" >> /root/restart_datanodes.sh
		for (( i=1; i<=$NUM_WORKERS; ++i));
		do
			echo "docker start node$i | tee ${HWX_LOGS}/docker.log" >> /root/restart_datanodes.sh
		done
	
		chmod 755 /root/restart_datanodes.sh
	fi
fi

echo "Starting Docker Containers"
cd /data/nvent_hwx/docker
for (( i=1; i<=$NUM_WORKERS; ++i));
do
	cat >> /data/nvent_hwx/docker/docker-compose.yml <<EOF
  node$i:
    image: nvent_hwx/agent_node
    hostname: node$i
    container_name: node$i
    privileged: true
    dns: 8.8.8.8
    network_mode: "bridge"
    environment:
      - AMBARI_SERVER=namenode
    links:
      - namenode:namenode
    ports:
      - "8440"
      - "8441"
      - "22"
    volumes:
      - /data/node1/hadoop:/hadoop
      - /usr/hdp
      - /var/log
      - /etc/hosts:/etc/hosts
    depends_on:
      - resourcemanager
EOF
done

docker-compose up -d

listip > /tmp/hosts
cat /tmp/hosts >> /etc/hosts
updateip


# Start the Namenode/Ambari Server 
# echo "Starting Namenode/Ambari Server..."
# DOCKER_NODE=namenode
# mkdir -p /data/$DOCKER_NODE/hadoop
# docker run --privileged=true -d --dns 8.8.8.8 -p 8080:8080 -p 3000:3000 -p 8440:8440 -p 8441:8441 -p 50070:50070 -p 8020:8020 -e AMBARI_SERVER=namenode -e BLUEPRINT_BASE=${BLUEPRINT_BASE} -v /data/$DOCKER_NODE/hadoop:/hadoop -v /usr/hdp -v /var/log --name $DOCKER_NODE -h $DOCKER_NODE -i -t nvent_hwx/master_server_node
# IP_namenode=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" $DOCKER_NODE)
# echo "Namenode/Ambari Server started at $IP_namenode"

# Start the ResourceManager
# echo "Starting ResourceManager..."
# DOCKER_NODE=resourcemanager
# mkdir -p /data/$DOCKER_NODE/hadoop
# docker run --privileged=true -d --link namenode:namenode -e namenode_ip=$IP_namenode -e AMBARI_SERVER=namenode --dns 8.8.8.8 -p 8088:8088 -p 8032:8032 -p 50060:50060 -p 8081:8081 -p 8030:8030 -p 8050:8050 -p 8025:8025 -p 8141 -p 8440 -p 8441 -p 19888:19888 -p 45454 -p 10020:10020 -p 22 -v /data/$DOCKER_NODE/hadoop:/hadoop -v /usr/hdp -v /var/log --name $DOCKER_NODE -h $DOCKER_NODE -i -t nvent_hwx/agent_node
# IP_resourcemanager=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" $DOCKER_NODE)
# echo "ResourceManager running on $IP_resourcemanager"

# Start the Hive/Oozie Server
# echo "Starting a Hive/Oozie server..."
# DOCKER_NODE=hiveserver
# mkdir -p /data/$DOCKER_NODE/hadoop
# docker run --privileged=true -d --link namenode:namenode -e namenode_ip=$IP_namenode -e AMBARI_SERVER=namenode --dns 8.8.8.8 -p 11000:11000 -p 2181 -p 50111:50111 -p 9083 -p 10000 -p 9999:9999 -p 9933:9933 -p 22 -p 8440 -p 8441 -v /data/$DOCKER_NODE/hadoop:/hadoop -v /usr/hdp -v /var/log --name $DOCKER_NODE -h $DOCKER_NODE -i -t nvent_hwx/agent_node
# IP_hive=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" $DOCKER_NODE)
# echo "Hive/Oozie running on $IP_hive"

# Start the worker nodes
# echo "Starting $NUM_WORKERS worker nodes..."
# for (( i=1; i<=$NUM_WORKERS; ++i));
# do
# nodename="node$i"
# mkdir -p /data/$nodename/hadoop
# docker run --privileged=true -d --dns 8.8.8.8 -h $nodename --name $nodename -p 22 --link namenode:namenode -e AMBARI_SERVER=namenode -p 8440 -p 8441 -v /data/$nodename/hadoop:/hadoop -v /usr/hdp -v /var/log -i -t nvent_hwx/agent_node
# IP_node=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" $nodename)
# echo "Started worker $nodename on IP $IP_node"
# done

