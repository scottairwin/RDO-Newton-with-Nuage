#!/bin/bash

# Note, run: "chmod u+x newton.sh"

# Parameters
SCP_SERVER="root@1.2.3.4:/share/nfs/nuage/4.0r8/extracted"            # ALL NUAGE FILES MUST BE LOCATED HERE (see README.md file)
TEMP_DIR="/tmp/nuage/"                                                # TEMP DIRECTORY WHERE ALL FILES WILL BE LOCATED
KEYSTONE_ADMIN_TOKEN="d34b4dbd64704647a61258adb6b0823a"               # KEYSTONE ADMIN TOKEN FOUND IN "head -20 /etc/keystone/keystone.conf"
NET_PARTITION_NAME="newton"                                           # OpenStack default Net Partition, will display as tenant name in VSD
CONFIG_MARIADB_PW="8d3dab21494e4b17"                                  # MYSQL DB PASSWORD FOUND IN "vi /root/packstack-answers*.txt"
OS_CTLR_IP="192.168.1.172"                                            # OPENSTACK (newton, PACKSTACK) IP ADDRESS
VSD_IP="192.168.1.181"                                                # VSD IP ADDRESS

# Generate SSH key
ssh-keygen -t rsa
ssh-copy-id root@1.2.3.4

# Edit nova file
sed -i 's/ovs_bridge=br-int/ovs_bridge=alubr0/g' /etc/nova/nova.conf
sed -i 's/metadata_proxy_shared_secret =.*$/metadata_proxy_shared_secret =NuageNetworksSharedSecret/g' /etc/nova/nova.conf
sed -i 's/use_forwarded_for=.*$/use_forwarded_for=True/g' /etc/nova/nova.conf
sed -i 's/#instance_name_template=instance-%08x/instance_name_template=instance-%08x/g' /etc/nova/nova.conf

# Edit neutron file
sed -i 's@#api_extensions_path =@api_extensions_path =/usr/lib/python2.7/site-packages/nuage_neutron/plugins/nuage/extensions/@g' /etc/neutron/neutron.conf
sed -i 's/core_plugin=.*$/core_plugin=nuage_neutron.plugins.nuage.plugin.NuagePlugin/g' /etc/neutron/neutron.conf
sed -i 's/service_plugins=/#service_plugins=/g' /etc/neutron/neutron.conf

# Remove neutron services
systemctl stop neutron-dhcp-agent.service
systemctl is-active neutron-dhcp-agent.service >/dev/null 2>&1 && echo neutron-dhcp-agent = Active || echo neutron-dhcp-agent = Disabled
systemctl stop neutron-l3-agent.service
systemctl is-active neutron-l3-agent.service >/dev/null 2>&1 && echo neutron-l3-agent = Active || echo neutron-l3-agent = Disabled
systemctl stop neutron-metadata-agent.service
systemctl is-active neutron-metadata-agent.service >/dev/null 2>&1 && echo neutron-metadata-agent = Active || echo neutron-metadata-agent = Disabled
systemctl stop neutron-openvswitch-agent.service
systemctl is-active neutron-openvswitch-agent.service >/dev/null 2>&1 && echo neutron-openvswitch-agent = Active || echo neutron-openvswitch-agent = Disabled
systemctl stop neutron-netns-cleanup.service
systemctl is-active neutron-netns-cleanup.service >/dev/null 2>&1 && echo neutron-netns-cleanup = Active || echo neutron-netns-cleanup = Disabled
systemctl stop neutron-netns-cleanup.service
systemctl is-active neutron-netns-cleanup.service >/dev/null 2>&1 && echo neutron-netns-cleanup = Active || echo neutron-netns-cleanup = Disabled
systemctl disable neutron-dhcp-agent.service
systemctl disable neutron-l3-agent.service
systemctl disable neutron-metadata-agent.service
systemctl disable neutron-openvswitch-agent.service
systemctl disable neutron-netns-cleanup.service
systemctl disable neutron-ovs-cleanup.service

# Install Nuage RPMs
mkdir -p $TEMP_DIR
cd $TEMP_DIR
scp $SCP_SERVER/newton/el7/nuagenetlib*.rpm $TEMP_DIR
scp $SCP_SERVER/newton/el7/nuage-openstack-neutron*.rpm  $TEMP_DIR
scp $SCP_SERVER/newton/el7/nuage-openstack-neutronclient*.rpm $TEMP_DIR
scp $SCP_SERVER/newton/el7/nuage-openstack-heat*.rpm $TEMP_DIR
scp $SCP_SERVER/newton/el7/nuage-openstack-horizon*.rpm $TEMP_DIR

rpm -ivh nuagenetlib*.rpm
rpm -ivh nuage-openstack-neutron*.rpm
rpm -ivh nuage-openstack-heat*.rpm
rpm -ivh nuage-openstack-horizon*.rpm

mkdir -p /etc/neutron/plugins/nuage/

echo "
[DATABASE]
connection = mysql://nuage_neutron:password@$OS_CTLR_IP/nuage_neutron?charset=utf8

[KEYSTONE]
keystone_service_endpoint = http://$OS_CTLR_IP:35357/v2.0/
keystone_admin_token = $KEYSTONE_ADMIN_TOKEN

[RESTPROXY]
default_net_partition_name = $NET_PARTITION_NAME
auth_resource = /me
server = $VSD_IP:8443
organization = csp
serverauth = csproot:csproot
serverssl = True
base_uri = /nuage/api/v4_0
default_floatingip_quota = 254" > '/etc/neutron/plugins/nuage/nuage_plugin.ini'

# Insert into mysql
mysql -uroot -p$CONFIG_MARIADB_PW <<MYSQL_SCRIPT
CREATE DATABASE nuage_neutron;
GRANT ALL PRIVILEGES ON nuage_neutron.* TO 'nuage_neutron'@'localhost' identified by 'password';
GRANT ALL PRIVILEGES ON nuage_neutron.* TO 'nuage_neutron'@'%' identified by 'password';
GRANT ALL PRIVILEGES ON nuage_neutron.* TO 'nuage_neutron'@'$OS_CTLR_IP' identified by 'password';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Migrate new plugin
rm -rf /etc/neutron/plugin.ini
ln -s /etc/neutron/plugins/nuage/nuage_plugin.ini /etc/neutron/plugin.ini

neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/nuage/nuage_plugin.ini upgrade head

# Enable Nuage CMS ID:
mkdir -p $TEMP_DIR/upgrade
cd /tmp/nuage/upgrade
scp $SCP_SERVER/nuage-openstack-upgrade*.tar.gz $TEMP_DIR/upgrade
tar -xzvf nuage-openstack-upgrade*.tar.gz
python generate_cms_id.py --config-file /etc/neutron/plugins/nuage/nuage_plugin.ini

# Restart services
systemctl restart openstack-nova-api
systemctl is-active openstack-nova-api >/dev/null 2>&1 && echo nova-api = Restarted || echo nova-api = Error
systemctl restart openstack-nova-scheduler
systemctl is-active openstack-nova-scheduler >/dev/null 2>&1 && echo nova-scheduler = Restarted || echo nova-scheduler = Error
systemctl restart openstack-nova-conductor
systemctl is-active openstack-nova-conductor >/dev/null 2>&1 && echo nova-conductor = Restarted || echo nova-conductor = Error
systemctl restart neutron-server
systemctl is-active neutron-server >/dev/null 2>&1 && echo neutron-server = Success || echo neutron-server = Error
