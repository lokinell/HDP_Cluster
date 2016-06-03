FROM nvent_hwx/base_node

MAINTAINER Lindsay Weir, lweir@nventdata.com

# Install and configure Ambari agent
RUN yum -y install --nogpgcheck ambari-agent

RUN sed -i '/^hostname=.*$/c\hostname=namenode' /etc/ambari-agent/conf/ambari-agent.ini

COPY start-scripts/ /root/start-scripts

VOLUME /hadoop
VOLUME /usr/hdp
VOLUME /var/log

ENTRYPOINT ["/root/scripts/startup.sh"]
