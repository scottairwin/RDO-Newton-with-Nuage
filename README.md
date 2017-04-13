## Intended for PoCs and Labs only!
# RDO-Newton-with-Nuage
RDO PackStack Newton with Nuage Integration BASH Script

These simple to use bash scripts will help you understand just how easy it is to install and integrate an OpenStack installation consisting of 1 controller and 2 compute hosts.

## Prerequisites include the following:
- 3x CentOS 7.3 with yum update and epel enabled (1 as the Controller and 2 for Compute Nodes)
- Nuage v4.0R8 VSD installed
- Nuage v4.0R8 VSCs (2) installed
- DNS Server with the OpenStack Contollers FQDN
- NTP Server for both controller and compute nodes
- NFS Server for the Nuage bits repo (see below for NFS file directory layout requirements)
- Internet Connection to both the Controller and Compute Nodes

## NFS file directory layout
- /extracted
- nuage-metadata-agent-4.0.8-172.el7.x86_64.rpm
- nuage-openstack-upgrade-4.0.8-170.tar.gz
- nuage-openvswitch-4.0.8-172.el7.x86_64.rpm
- /extracted/newton/el7
- nuage-openstack-heat-7.0.0-4.0.8_170_nuage.noarch.rpm
- nuage-openstack-horizon-10.0.0-4.0.8_170_nuage.noarch.rpm
- nuage-openstack-neutron-9.0.0-4.0.8_170_nuage.noarch.rpm
- nuage-openstack-neutronclient-6.0.0-4.0.8_170_nuage.noarch.rpm
- nuagenetlib-9.0.0-4.0.8_170_nuage.noarch.rpm

## Change the NFS Server IP within both .bash scripts to your own NFS Server
```
root@1.2.3.4:/share/nfs/nuage/4.0r8/extracted
```

The two scripts in this repo will allow you install all required Nuage plugin's and connect the environment to the Nuage VCS deployment.

Have fun and leave comments if you'd you like to see more like this!!
