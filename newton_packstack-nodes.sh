#!/bin/bash

# Note, run: "chmod u+x vrs.sh"

# Parameters
SCP_SERVER="root@1.2.3.4:/share/nfs/nuage/4.0r8/extracted/"             # ALL NUAGE FILES MUST BE LOCATED HERE EXTRACTED
TEMP_DIR="/tmp/nuage/"                                                  # TEMP DIRECTORY WHERE ALL FILES WILL BE LOCATED
ACTIVE_CONTROLLER="172.16.1.182"                                        # IP of VSC1 CTRL Interface
STANDBY_CONTROLLER="172.16.1.183"                                       # IP of VSC2 CTRL Interface
scp_user_access="root@1.2.3.4"                                          # SSH login to scp server for unrestricted access

# Generate SSH key
ssh-keygen -t rsa
ssh-copy-id $scp_user_access

# Install Nuage RPMs
mkdir -p $TEMP_DIR
cd $TEMP_DIR
scp $SCP_SERVER/nuage-openvswitch*.rpm $TEMP_DIR

# Resolve dependancies and enable repository
rpm -Uvh http://mirror.pnl.gov/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/CentOS-Base.repo
yum -y update

# Install openvswitch (apply to VRS/VRS-G and OpenStack Nodes)
cd $TEMP_DIR
yum -y remove python-openvswitch
yum -y remove openvswitch
yum -y install nuage-openvswitch*.rpm
yum -y remove openvswitch
yum -y install nuage-openvswitch*.rpm

sed -i 's/# ACTIVE_CONTROLLER=/ACTIVE_CONTROLLER='"$ACTIVE_CONTROLLER"'/g' /etc/default/openvswitch
sed -i 's/# STANDBY_CONTROLLER=/STANDBY_CONTROLLER='"$STANDBY_CONTROLLER"'/g' /etc/default/openvswitch

# Restart openvswitch
systemctl restart openvswitch
systemctl is-active openvswitch >/dev/null 2>&1 && echo openvswitch = Restarted || echo nova-api = Error

# Install metadata agent
cd $TEMP_DIR
scp $SCP_SERVER/nuage-metadata-agent*.rpm $TEMP_DIR
rpm -ivh nuage-metadata-agent*.rpm

# Make changes to the nova.conf file
sed -i 's/ovs_bridge=br-int/ovs_bridge=alubr0/g' /etc/nova/nova.conf
sed -i 's/#service_metadata_proxy=false/service_metadata_proxy=true/g' /etc/nova/nova.conf
sed -i 's/#metadata_proxy_shared_secret =.*$/metadata_proxy_shared_secret =NuageNetworksSharedSecret/g' /etc/nova/nova.conf
sed -i 's/#use_forwarded_for=.*$/use_forwarded_for=true/g' /etc/nova/nova.conf
sed -i 's/#instance_name_template=instance-%08x/instance_name_template=instance-%08x/g' /etc/nova/nova.conf

# restart nova-compute and openvswitch
systemctl restart openstack-nova-compute
systemctl is-active openstack-nova-compute >/dev/null 2>&1 && echo nova-compute = Active || echo nova-compute = Not Active
systemctl restart openvswitch
systemctl is-active openvswitch >/dev/null 2>&1 && echo openvswitch = Active || echo openvswitch = Disabled
#END
