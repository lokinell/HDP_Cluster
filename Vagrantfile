# -*- mode: ruby -*-
# vi: set ft=ruby :

##########################################################################################
#
# HDP_Cluster
#
# Written By: Lindsay Weir
#             lweir@nventdata.com
#
# Vagrant script to build host server running Docker to build a multi-node Hortonworks
# HDP Cluster.
# Features:
#			- Supports CentOS 6 and 7
#			- Host VM can be customized - memory, disk size, cpus, IP subnet
#			- Version of Ambari and HDP can be specified. (Responsibility of the user to
#       to ensure compatability between versions)
#			- Oracle Java Version and install path can be specified
#			- Supports local repositories for Ambari, HDP, HDP-UTILS. Will dynamically build
#				httpd server on host server if LOCAL_REPO path is provided
#			- Supports optional local repo with base OS files (and the downloaded Oracle JDK
#				if the OS_EXTRAS_REPO variable is specified. This will be a directory located
#				under the LOCAL_REPO path)
#			- Ambari blueprint can be specified for configuring the cluster
#			- Additional DataNodes can be specified to be built
#
# Work based on the CentOS 6 HDP Docker containers by Rich Raposa, rich@hortonworks.com
# (https://github.com/HortonworksUniversity/)
#
##########################################################################################

if !File.file?(File.join(Dir.home, '.ssh/id_rsa.pub'))
  puts "[INFO]: SSH Public Key Does Not Exist, Creating SSH Keys"
  if !system( "echo y | ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''" )
    puts "[ERROR]: Failed to create SSH Keys on local server"
    exit
  end
end  
ssh_key = File.open(File.join(Dir.home, '.ssh/id_rsa.pub'), "rb").read
puts "[INFO]: SSH Public Key = #{ssh_key}"


HOSTNAME_PREFIX = "HDP"
NUM_HOST_SERVERS = "1"	# Number of Host Servers to create

#MEMORY = "12288"
MEMORY = "10240"
#MEMORY = "8192"
CPUS = "4"
DISK_SIZE = "100"
NUM_DISKS = "1"

# CENTOS 6.7
#VAGRANT_IMAGE = "box-cutter/centos67-docker"

# CENTOS 7.2
VAGRANT_IMAGE = "box-cutter/centos72-docker"

# Vagrant Subnet the host servers will be built on (starting at .2)
IP_NETWORK = "192.168.50."

# Blueprint
# To add a custom blueprint, add the <file>.blueprint to the HDP_Clusters/blueprints
# directory. The <file>.hostmapping file will be dynamically created.
# Note: Additional ports may need to be specified in the
# HDP_Clusters/docker/docker-compose.yml file to be exposed on the host vm.

#BLUEPRINT = "nvent"
BLUEPRINT = "nvent_small"

# Additional Datanodes (node1, node2, node3) that will be built. More DataNodes will need
# the MEMORY on host vm to be increased accordingly.
#ADDITIONAL_DATANODES = "0"
ADDITIONAL_DATANODES = "1"


# Optional local Repo directory to mount in the host under /repos.
# A local httpd server will be created on the vagrant host server so that all AMBARI_REPO,
# HDP_REPO, HDP_UTILS_REPO paths will be under the http://<vagrant_host>/
# path. If the OS_EXTRAS_REPO is specified, then this must be under the same location of
# the LOCAL_REPO directory.
LOCAL_REPO = ""
OS_EXTRAS_REPO = ""


# Ambari 2.1.2.1/HDP 2.3.2.0
#AMBARI_VERSION = "2.1.2.1"
#AMBARI_REPO = "http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.1.2.1/ambari.repo"
#HDP_VERSION = "2.3.2.0"
#HDP_REPO = "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.3.2.0/hdp.repo"

# Ambari 2.2.1.0/HDP 2.3.4.7
#AMBARI_VERSION = "2.2.1.0"
#AMBARI_REPO = "http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.2.1.0/ambari.repo"
#HDP_VERSION = "2.3.4.7"
#HDP_REPO = "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.3.4.7/hdp.repo"

# Ambari 2.2.2.0/HDP 2.4.2.0
AMBARI_VERSION = "2.2.2.0"
AMBARI_REPO = "http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.2.2.0/ambari.repo"
HDP_VERSION = "2.4.2.0"
HDP_REPO = "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.4.2.0/hdp.repo"

# Only needed if we are not using the default http://hortonworks/hdp.repo file (as it is included in this)
HDP_UTILS_VERSION = "1.1.0.20"
HDP_UTILS_REPO = "http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.20/repos/centos6"


# JAVA JDK
# This can be directly downloaded from the Oracle web site, or if the file names are
# provided (.tar.gz and .zip for the JCE) then these must live in the OS_EXTRAS_REPO
JAVA_INSTALL_PATH = "/usr/jdk64/jdk1.8.0_92"
JDK = "http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-x64.tar.gz"
JCE = "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip"
#JDK = "jdk-8u92-linux-x64.tar.gz"
#JCE = "jce_policy-8.zip"


##########################################################################################
# Local Repository Example
#
# LOCAL_REPO = "/Volumes/Seagate\ Backup\ Plus\ Drive/Repos/"
# #OS_EXTRAS_REPO = "HDP_CentOS6.7"
# OS_EXTRAS_REPO = "HDP_CentOS7.2"
# AMBARI_VERSION = "2.2.2.0"
# AMBARI_REPO = "AMBARI-2.2.2.0/centos6/2.2.2.0-460/"
# HDP_VERSION = "2.4.2.0"
# HDP_REPO = "HDP/centos6/2.x/updates/2.4.2.0/"
# HDP_UTILS_VERSION = "1.1.0.20"
# HDP_UTILS_REPO = "HDP-UTILS-1.1.0.20/repos/centos6/"
# 
# JAVA_INSTALL_PATH = "/usr/jdk64/jdk1.8.0_92"
# JDK = "jdk-8u92-linux-x64.tar.gz"
# JCE = "jce_policy-8.zip"
#
##########################################################################################




# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "#{VAGRANT_IMAGE}"

	(1 .. Integer("#{NUM_HOST_SERVERS}")).each do |i|
		hostname = "#{HOSTNAME_PREFIX}-#{i}"

		ip = Integer(i) + 1

    config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
      vb.memory = "#{MEMORY}"
      vb.cpus = "#{CPUS}"
    end
    
		# Only mount local repo directory on the host if the path exists
		if "#{LOCAL_REPO}" != ""
			if File.directory?(File.expand_path("#{LOCAL_REPO}"))
				config.vm.synced_folder "#{LOCAL_REPO}", "/repos"
			end
		end
		config.vm.define "#{hostname}" do |node|
#			puts "[INFO]: Host: #{hostname}, IP: #{IP_NETWORK}#{ip}"
			node.vm.network "private_network", ip: "#{IP_NETWORK}#{ip}"
			node.vm.hostname="#{hostname}"		

			(1 .. Integer("#{NUM_DISKS}")).each do |d|
				file_for_disk = "./#{hostname}_disk#{d}.vmdk"

#				puts "[INFO]: Creating Disk: #{hostname} - #{file_for_disk}"
        node.vm.provider "virtualbox" do |v|
					unless File.exist?(file_for_disk)
						 v.customize ['createhd', 
													'--filename', file_for_disk, 
													'--size', 1024 * Integer("#{DISK_SIZE}"),
													'--format', 'VMDK']
						 v.customize ['storageattach', :id, 
													'--storagectl', 'SATA Controller', 
													'--port', 1 + Integer("#{d}") - 1,
													'--device', 0,
													'--type', 'hdd',
													'--medium', file_for_disk]
					end
				 end
			 end
			 node.vm.provision "shell", inline: <<-SHELL
echo "#{ssh_key}" >> /home/vagrant/.ssh/authorized_keys
SHELL

			 node.vm.provision :shell, :path => "bootstrap.sh", :args => [
			  "HOST_IP=192.168.50.#{ip}", "AMBARI_VERSION=#{AMBARI_VERSION}",
				"AMBARI_REPO=#{AMBARI_REPO}", "HDP_VERSION=#{HDP_VERSION}",
				"HDP_REPO=#{HDP_REPO}", "HDP_UTILS_VERSION=#{HDP_UTILS_VERSION}",
				"HDP_UTILS_REPO=#{HDP_UTILS_REPO}", "BLUEPRINT=#{BLUEPRINT}",
				"ADDITIONAL_DATANODES=#{ADDITIONAL_DATANODES}", "OS_EXTRAS_REPO=#{OS_EXTRAS_REPO}",
				"JDK=#{JDK}", "JCE=#{JCE}", "JAVA_INSTALL_PATH=#{JAVA_INSTALL_PATH}"
				]

		 end

	end

end
