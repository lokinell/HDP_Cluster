FROM nvent_hwx/base_node

MAINTAINER Lindsay Weir, lweir@nventdata.com

RUN wget -nv http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.4.2.0/hdp.repo -O /etc/yum.repos.d/HDP.repo
#COPY conf/HDP.repo /etc/yum.repos.d/HDP.repo

# Install and configure Ambari server and agent
RUN yum clean all
RUN yum -y install --nogpgcheck ambari-server ambari-agent
RUN ambari-server setup -s -j /usr/jdk64/jdk1.8.0_60

COPY scripts/ /root/scripts
COPY start-scripts/ /root/start-scripts 
COPY blueprints/ /root/blueprints
COPY repos /root/repos

VOLUME /hadoop
VOLUME /usr/hdp
VOLUME /var/log

ENTRYPOINT ["/root/scripts/startup.sh"]