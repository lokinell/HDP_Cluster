#HDP_Cluster

Vagrant script to build host server running multi-node Hortonworks HDP Cluster on
Docker containers. By default this will create a 4 node HDP Cluster.

By default, the following nodes are created as docker containers:

- namenode
- resourcemanager
- hiveserver
- node1

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

##Prerequisites

Both Vagrant and Oracle Virtualbox are required.
The Virtualbox image used will install and run Docker so no additional installation is required.

Downloads for Vagrant and Oracle Virtualbox can be found in the following locations:

- Vagrant [https://www.vagrantup.com/](https://www.vagrantup.com/)
- Oracle Virtualbox [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)

##Optional Local repositories

**HDP_Cluster** can take advantage of local HDP Repositories for the Ambari, HDP, and HDP-UTILS installations. If local repositories are not desired, then the installation will use the public repositories as published by Hortonworks by default.
These can be manually downloaded as per the instructions on Hortonworks website below:

[```http://docs.hortonworks.com/HDPDocuments/Ambari-2.2.2.0/bk_Installing_HDP_AMB/content/_obtaining_the_repositories.html```](http://docs.hortonworks.com/HDPDocuments/Ambari-2.2.2.0/bk_Installing_HDP_AMB/content/_obtaining_the_repositories.html)

###HDP_CreateLocalRepo
Alternately, you can take advantage of the **HDP_CreateLocalRepo** utility to automatically download the HDP repositories through a command line tool interactively, or automatically (which could be added to a cron job to download the latest release nightly).
This project can also be found on github at [```https://github.com/NVENT-LindsayWeir/HDP_CreateLocalRepo```](https://github.com/NVENT-LindsayWeir/HDP_CreateLocalRepo)

This project will download all three repositories and extract the files automatically. An interactive menu is available that will discover all the available versions and prompt you as to which platform (centos 6 or 7) and then which Ambari, HDP, and HDP-UTILS versions you want to download.
Optionally a single flag can be provided that will automatically just download the latest release.

###HDP_Repos
An additional utility **HDP_Repos** is also available that will download core OS files (either CentOS 6 or 7) and the Oracle Java JDK and JCE files into a standalone repository.
This is useful if you are wanting to perform multiple cluster builds and do not want to download all the files each time.
There are still files that are downloaded from external locations but this can reduce some time with the files being local.

This project can be found on github at [```https://github.com/NVENT-LindsayWeir/HDP_Repos```](https://github.com/NVENT-LindsayWeir/HDP_Repos)

The project will spin up a vagrant box (either CentOS 6 or 7 - can be changed in the Vagrantfile) and download and create the repository directory at the root level of the project. The resulting directory(s) must be copied to the same directory location as the **LOCAL_REPO** path being used.

##Configuration Options

There are many options that can be modified for building the HDP cluster. These can be broken down into the following locations:

- Vagrantfile
- Blueprints
- Docker Ports (needed if additional services are exposed in Blueprints)

We will go through each of these in more detail below.

###Vagrantfile

Most of the configurations can be found in the Vagrantfile




Variable | Default Value |Definition
---------|---------------|----------
MEMORY | 10240 | Memory for VM
CPUS | 4 | Number of CPU Cores
DISK_SIZE | 100 | Size of disk on VM to store cluster DataNodes
VAGRANT_IMAGE | box-cutter/centos72-docker | Base VM Image with docker installed
IP_NETWORK | 192.168.50. | Subnet that Vagrant VM will be built on (IP starting at .2)
BLUEPRINT | nvent_small | Blueprint to use
ADDITIONAL_DATANODES | 1 | Number of additional DataNodes to create. Additional nodes are node1, node2, ...
LOCAL_REPO | | Optional local repository directory, e.g. "/Users/myname/HDP/Repos". This will be mounted to the VM as the /repos directory and if present an httpd server will be created on the VM and used as the path for repos below
OS_EXTRAS_REPO | | Optional local OS repos in directory below LOCAL_REPO, e.g. "HDP_CentOS7.2"
AMBARI_VERSION | 2.2.2.0 | Full version number for Ambari
AMBARI_REPO | http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.2.2.0/ambari.repo | URL to Ambari Repo (Hortonworks public repo, or internal URL). If a path is provided (e.g. AMBARI-2.2.2.0/centos6/2.2.2.0-460/) then this must live below the LOCAL_REPOS directory path above
HDP_VERSION | 2.4.2.0 | Full version number for HDP
HDP_REPO | http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.4.2.0/hdp.repo | URL to HDP Repo (Hortonworks public repo, or internal URL). If a path is provided (e.g. HDP/centos6/2.x/updates/2.4.2.0/) then this must live below the LOCAL_REPOS directory path above

HDP_UTILS_VERSION | 1.1.0.20 | Full version number for HDP-UTILS
HDP_UTILS_REPO | http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.20/repos/centos6 | URL to HDP Repo (Hortonworks public repo, or internal URL). If a path is provided (e.g. HDP-UTILS-1.1.0.20/repos/centos6/) then this must live below the LOCAL_REPOS directory path above
JAVA_INSTALL_PATH | /usr/jdk64/jdk1.8.0_92 | Installation directory that the Oracle Java JDK will be installed to
JDK | http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz | Location to the public Oracle JDK download. If a local filename is provided then this will be the file found in the OS_EXTRAS_REPO repo directory (e.g. jdk-8u92-linux-x64.tar.gz)
JCE | http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip | Location to the public Oracle JCE extentions. If a local filename is provided then this will be the file found in the OS_EXTRAS_REPO repo directory (e.g. jce_policy-8.zip)
 

###Blueprints

Custom blueprints can be created. Any custom blueprint must be placed into the **blueprints/** directory with <blueprint name>.blueprint name format. No *.hostmapping file is necessary as it will be dynamically generated.
The host_groups should follow the format as found in the **nvent_small.blueprint** file with the groups as follows:

- namenode
- resourcemanager
- hiveserver
- worker (for the node1, node2, node3 DataNodes)

If the Ambari version is >= 2.2.2.X then GRAFANA will be added to the namenode group if it hasn't already been defined.
The **stack_version** will be dynamically updated based on the version being installed.

Any external ports that must be accessed (i.e. Ranger UI for example) must be added to the **nvent_hwx/docker/docker-compose.yml** for the appropriate host

###Docker Ports

Any additional services or components that are installed (either post installation or as part of a new blue print) may need additional ports to be exposed on the Vagrant VM. Any ports that need to be exposed to the local network need to be mapped in the **docker-compose.yml** file. Thus, only a single port can be mapped for external services.


##Building the Cluster

To build the cluster, change into the **HDP_Cluster** directory and run the following:

```
vagrant up
```

To destroy the cluster once you are finished with it, from the same directory, run the following:

```
vagrant destroy -f
```

##Accessing the Cluster

To access the cluster once the initial VM and docker containers are built.

```
vagrant ssh -c "sudo su -"
```

You can then ssh directly to any of the docker containers using:

```
ssh namenode
ssh resourcemanager
ssh hiveserver
ssh node1
```

##Accessing Ambari

To connect to Ambari, the following URL can be used from your browser - [http://192.168.50.2:8080/](http://192.168.50.2:8080/):

```
http://192.168.50.2:8080/
```
This assumes the network has not been modified in the **Vagrantfile** with the **IP_NETWORK** variable. Otherwise, use the network prefix defined there.

If some of the links within Ambari redirect to one of the docker containers (i.e. GRAFANA will redirect to http://namenode:3000) then these will not work.
Assuming the port has been exposed in the docker-compose.yml file, you can then change the URL to [http://192.168.50.2:3000/](http://192.168.50.2:3000/) to access GRAFANA.
 