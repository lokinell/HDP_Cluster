#HDP_Cluster

Vagrant script to build host server running multi-node Hortonworks HDP Cluster on
Docker containers.

##Features:
- Supports CentOS 6 and 7
- Host VM can be customized - memory, disk size, cpus, IP subnet
- Version of Ambari and HDP can be specified. (Responsibility of the user to to ensure compatability between versions)
- Oracle Java Version and install path can be specified
- Supports local repositories for Ambari, HDP, HDP-UTILS. Will dynamically build httpd server on host server if LOCAL_REPO path is provided
- Supports optional local repo with base OS files (and the downloaded Oracle JDK if the OS_EXTRAS_REPO variable is specified. This will be a directory located under the LOCAL_REPO path)
- Ambari blueprint can be specified for configuring the cluster
- Additional DataNodes can be specified to be built

Work based on the CentOS 6 HDP Docker containers by Rich Raposa, rich@hortonworks.com (https://github.com/HortonworksUniversity/)
