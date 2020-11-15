// ----- NSX-T Data -----
data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = "PROD-OVERLAY-TZ"
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  display_name = "Edge-Cluster"
}

data "nsxt_policy_tier0_gateway" "t0_gateway" {
  display_name = "T0-Prod"
}

// ----- NSX-T Resources Creation -----

// Create a DHCP Server
resource "nsxt_policy_dhcp_server" "tier_dhcp" {
  nsx_id = "DHCP-Server-IDPS"
  display_name = "DHCP-Server-IDPS"
  description      = "DHCP server for IDPS Segments"
  server_addresses = ["172.50.0.7/24"]
}

// Create a new T1 GW for IDPS Demo
resource "nsxt_policy_tier1_gateway" "t1_gateway" {
  nsx_id                    = "T1-GW-IDPS"
  display_name              = "T1-GW-IDPS"
  description               = "T1 GW for IDPS Demo"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
  dhcp_config_path          = nsxt_policy_dhcp_server.tier_dhcp.path
  failover_mode             = "PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "false"
  enable_standby_relocation = "false"
  tier0_path                = data.nsxt_policy_tier0_gateway.t0_gateway.path
  route_advertisement_types = ["TIER1_CONNECTED"] // "TIER1_NAT"
  pool_allocation           = "ROUTING"
}
  
// Create an External segment for the threat VM
resource "nsxt_policy_segment" "external" {
  nsx_id              = "IDPS-External-Segment"
  display_name        = "IDPS-External-Segment"
  description         = "External Segment for IDPS Demo"
  connectivity_path   = nsxt_policy_tier1_gateway.t1_gateway.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
    cidr = "192.114.209.1/24"
    dhcp_ranges = ["192.114.209.151-192.114.209.152"]

    dhcp_v4_config {
      server_address = "192.114.209.2/24"
      lease_time     = 36000
    }
  }
  advanced_config {
    connectivity = "ON"
  }
}

// Create a DMZ segment
resource "nsxt_policy_segment" "dmz" {
  nsx_id              = "IDPS-DMZ-Segment"
  display_name        = "IDPS-DMZ-Segment"
  description         = "DMZ Segment for IDPS Demo"
  connectivity_path   = nsxt_policy_tier1_gateway.t1_gateway.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
    cidr = "192.168.10.1/24"
    dhcp_ranges = ["192.168.10.100-192.168.10.200"]

    dhcp_v4_config {
      server_address = "192.168.10.2/24"
      lease_time     = 36000
    }
  }
  advanced_config {
    connectivity = "ON"
  }
}

// Create an Internal segment
resource "nsxt_policy_segment" "internal" {
  nsx_id              = "IDPS-Internal-Segment"
  display_name        = "IDPS-Internal-Segment"
  description         = "Internal Segment for IDPS Demo"
  connectivity_path   = nsxt_policy_tier1_gateway.t1_gateway.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
    cidr = "192.168.20.1/24"
    dhcp_ranges = ["192.168.20.100-192.168.20.200"]

    dhcp_v4_config {
      server_address = "192.168.20.2/24"
      lease_time     = 36000
    }
  }
  advanced_config {
    connectivity = "ON"
  }
}

/*
// Create SNAT and DNAT rules for DMZ Segment
resource "nsxt_policy_nat_rule" "rule1" {
  nsx_id              = "DMZ-SNAT"
  display_name        = "DMZ-SNAT"
  action              = "SNAT"
  source_networks     = ["192.168.10.0/24"]
  translated_networks = ["193.1.1.110"]
  gateway_path        = nsxt_policy_tier1_gateway.t1_gateway.path
}

resource "nsxt_policy_nat_rule" "rule2" {
  nsx_id               = "DMZ-DNAT-Production"
  display_name         = "DMZ-DNAT-Production"
  action               = "DNAT"
  translated_networks  = ["192.168.10.100/32"]
  destination_networks = ["193.1.1.100/32"]
  gateway_path         = nsxt_policy_tier1_gateway.t1_gateway.path
}

resource "nsxt_policy_nat_rule" "rule3" {
  nsx_id               = "DMZ-DNAT-Development"
  display_name         = "DMZ-DNAT-Development"
  action               = "DNAT"
  translated_networks  = ["192.168.10.101/32"]
  destination_networks = ["193.1.1.101/32"]
  gateway_path         = nsxt_policy_tier1_gateway.t1_gateway.path
}

// Create SNAT rules for Internal Segment
resource "nsxt_policy_nat_rule" "rule4" {
  nsx_id              = "Internal-SNAT"
  display_name        = "Internal-SNAT"
  action              = "SNAT"
  source_networks     = ["192.168.20.0/24"]
  translated_networks = ["193.1.1.120"]
  gateway_path        = nsxt_policy_tier1_gateway.t1_gateway.path
}
*/

// ----- vCenter Data -----
data "vsphere_datacenter" "datacenter" {
  name = "Montreal-DC"
}

data "vsphere_compute_cluster" "compute-external" {
  name = "Compute-K8S"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "compute-internal" {
  name = "Compute-VM"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore-external" {
  name = "OVNDC1ESXI3"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore-internal1" {
  name = "OVNDC1ESXI8"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore-internal2" {
  name = "OVNDC1ESXI9"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "vm-template" {
  name = "IDPS-Victim-VM"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "threat-vm-template" {
  name = "IDPS-External-VM"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

###Delay for vCenter to sync with NSX for Logical Switch
resource "null_resource" "before" {
  depends_on = [nsxt_policy_segment.external, nsxt_policy_segment.dmz, nsxt_policy_segment.internal]
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 20"
  }
  triggers = {
    "before" = null_resource.before.id
  }
}

resource "null_resource" "after" {
  depends_on = [null_resource.delay]
}

data "vsphere_network" "external" {
  depends_on = [null_resource.after]
  name  = nsxt_policy_segment.external.display_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "dmz" {
  depends_on = [null_resource.after]
  name = nsxt_policy_segment.dmz.display_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "internal" {
  depends_on = [null_resource.after]
  name = nsxt_policy_segment.internal.display_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

// ----- vCenter Resources Creation -----

// Create new VM for External
resource "vsphere_virtual_machine" "threat-vm" {
  depends_on = [nsxt_policy_segment.external, data.vsphere_network.external]
  name = "IDPS-Threat"
  datastore_id = data.vsphere_datastore.datastore-external.id
  resource_pool_id = data.vsphere_compute_cluster.compute-external.resource_pool_id
  guest_id = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.external.id
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.threat-vm-template.id
  }
  disk {
    label = "threat-vm.vmdk"
    size = 32
    thin_provisioned = true
  }
}

// Create new VM for DMZ
resource "vsphere_virtual_machine" "dmz1-vm" {
  depends_on = [nsxt_policy_segment.dmz, data.vsphere_network.dmz]
  name = "IDPS-WEB-Prod"
  datastore_id = data.vsphere_datastore.datastore-internal1.id
  resource_pool_id = data.vsphere_compute_cluster.compute-internal.resource_pool_id
  guest_id = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.dmz.id
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.vm-template.id
  }
  disk {
    label = "web1-vm.vmdk"
    size = 32
    thin_provisioned = true
  }
}

resource "vsphere_virtual_machine" "dmz2-vm" {
  depends_on = [nsxt_policy_segment.dmz, data.vsphere_network.dmz]
  name = "IDPS-WEB-Dev"
  datastore_id = data.vsphere_datastore.datastore-internal2.id
  resource_pool_id = data.vsphere_compute_cluster.compute-internal.resource_pool_id
  guest_id = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.dmz.id
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.vm-template.id
  }
  disk {
    label = "web2-vm.vmdk"
    size  = 32
    thin_provisioned = true
  }
}

// Create new VM for Internal
resource "vsphere_virtual_machine" "internal1-vm" {
  depends_on = [nsxt_policy_segment.internal, data.vsphere_network.internal]
  name = "IDPS-APP-Dev"
  datastore_id = data.vsphere_datastore.datastore-internal1.id
  resource_pool_id = data.vsphere_compute_cluster.compute-internal.resource_pool_id
  guest_id = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.internal.id
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.vm-template.id
  }
  disk {
    label = "app1-vm.vmdk"
    size = 32
    thin_provisioned = true
  }
}

resource "vsphere_virtual_machine" "internal2-vm" {
  depends_on = [nsxt_policy_segment.internal, data.vsphere_network.internal]
  name = "IDPS-APP-Prod"
  datastore_id = data.vsphere_datastore.datastore-internal2.id
  resource_pool_id = data.vsphere_compute_cluster.compute-internal.resource_pool_id
  guest_id = "ubuntu64Guest"
  network_interface {
    network_id = data.vsphere_network.internal.id
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.vm-template.id
  }
  disk {
    label = "app2-vm.vmdk"
    size  = 32
    thin_provisioned = true
  }
}
// ----- NSX-T Assign tags ----- 


# Assign the tags to the Threat VM
data "nsxt_policy_vm" "threat_vm" {
  depends_on = [vsphere_virtual_machine.threat-vm]
  display_name = "IDPS-Threat"
}

resource "nsxt_policy_vm_tags" "threat_vm_tag" {
  depends_on = [data.nsxt_policy_vm.threat_vm, vsphere_virtual_machine.threat-vm]
  instance_id = data.nsxt_policy_vm.threat_vm.instance_id
  tag {
    scope = "Environment"
    tag = "EXTERNAL"
  }
  tag {
    scope = "appName"
    tag = "threat"
  }
}

# Assign the tags to the DMZ VMs
data "nsxt_policy_vm" "dmz1_vm" {
  depends_on = [vsphere_virtual_machine.dmz1-vm]
  display_name = "IDPS-WEB-Prod"
}

data "nsxt_policy_vm" "dmz2_vm" {
  depends_on = [vsphere_virtual_machine.dmz2-vm]
  display_name = "IDPS-WEB-Dev"
}

resource "nsxt_policy_vm_tags" "dmz1_vm_tag" {
  depends_on = [data.nsxt_policy_vm.dmz1_vm, vsphere_virtual_machine.dmz1-vm]
  instance_id = data.nsxt_policy_vm.dmz1_vm.instance_id
  tag {
    scope = "Environment"
    tag = "Production"
  }
  tag {
    scope = "appName"
    tag = "Application-1"
  }
  tag {
    scope = "appTier"
    tag = "web-server"
  }
}

resource "nsxt_policy_vm_tags" "dmz2_vm_tag" {
  depends_on = [data.nsxt_policy_vm.dmz2_vm, vsphere_virtual_machine.dmz2-vm]
  instance_id = data.nsxt_policy_vm.dmz2_vm.instance_id
  tag {
    scope = "Environment"
    tag = "Development"
  }
  tag {
    scope = "appName"
    tag = "Application-2"
  }
  tag {
    scope = "appTier"
    tag = "web-server"
  }
}

# Assign the tags to the Internal VMs
data "nsxt_policy_vm" "internal1_vm" {
  depends_on = [vsphere_virtual_machine.internal1-vm]
  display_name = "IDPS-APP-Dev"
}

data "nsxt_policy_vm" "internal2_vm" {
  depends_on = [vsphere_virtual_machine.internal2-vm]
  display_name = "IDPS-APP-Prod"
}

resource "nsxt_policy_vm_tags" "internal1_vm_vm_tag" {
  depends_on = [data.nsxt_policy_vm.internal1_vm, vsphere_virtual_machine.internal1-vm]
  instance_id = data.nsxt_policy_vm.internal1_vm.instance_id
  tag {
    scope = "Environment"
    tag = "Development"
  }
  tag {
    scope = "appName"
    tag = "Application-2"
  }
  tag {
    scope = "appTier"
    tag = "app-server"
  }
}

resource "nsxt_policy_vm_tags" "internal2_vm_vm_tag" {
  depends_on = [data.nsxt_policy_vm.internal2_vm, vsphere_virtual_machine.internal2-vm]
  instance_id = data.nsxt_policy_vm.internal2_vm.instance_id
  tag {
    scope = "Environment"
    tag   = "Production"
  }
  tag {
    scope = "appName"
    tag   = "Application-1"
  }
  tag {
    scope = "appTier"
    tag   = "app-server"
  }
}

# Create Security Groups
resource "nsxt_policy_group" "env_threat" {
  display_name = "IDPS - External"
  criteria {
      condition {
         key = "Tag"
          member_type = "VirtualMachine"
          operator = "CONTAINS"
          value = "Environment|EXTERNAL"
      }
  }
}

resource "nsxt_policy_group" "env_prod" {
  display_name = "IDPS - Production Applications"
  criteria {
      condition {
          key = "Tag"
          member_type = "VirtualMachine"
          operator = "CONTAINS"
          value = "Environment|Production"
      }
  }
}

resource "nsxt_policy_group" "env_dev" {
  display_name = "IDPS - Development Applications"
  criteria {
      condition {
          key = "Tag"
          member_type = "VirtualMachine"
          operator = "CONTAINS"
          value = "Environment|Development"
      }
  }
}

/*
resource "nsxt_policy_group" "dnat_dev" {
  display_name = "IDPS - DNAT DEV IPSET"
  criteria {
    ipaddress_expression {
      ip_addresses = ["193.1.1.101"]
    }
  }
}

resource "nsxt_policy_group" "dnat_prod" {
  display_name = "IDPS - DNAT PROD IPSET"
  criteria {
    ipaddress_expression {
      ip_addresses = ["193.1.1.100"]
    }
  }
}
*/

# Create DFW Rules for Environment
resource "nsxt_policy_security_policy" "external_env" {
  display_name = "IDPS - External Env."
  category = "Environment"
  locked = false
  stateful = true
  tcp_strict = false

  rule {
    display_name = "allow any to production"
    source_groups = [nsxt_policy_group.env_threat.path]
    destination_groups = [nsxt_policy_group.env_prod.path] // nsxt_policy_group.dnat_prod.path
    action = "ALLOW"
    logged = false
    scope = [nsxt_policy_group.env_threat.path, nsxt_policy_group.env_prod.path]
  }
  rule {
    display_name = "allow any to development"
    source_groups = [nsxt_policy_group.env_threat.path]
    destination_groups = [nsxt_policy_group.env_dev.path] //nsxt_policy_group.dnat_dev.path
    action = "ALLOW"
    logged = false
    scope = [nsxt_policy_group.env_threat.path, nsxt_policy_group.env_dev.path]
  }
  rule {
    display_name = "deny all"
    source_groups = [nsxt_policy_group.env_threat.path]
    action = "DROP"
    logged = false
    scope = [nsxt_policy_group.env_threat.path]
  }
}

resource "nsxt_policy_security_policy" "prod_env" {
  display_name = "IDPS - Production Env."
  category = "Environment"
  locked = false
  stateful = true
  tcp_strict = false

  rule {
    display_name = "allow any to external"
    source_groups = [nsxt_policy_group.env_prod.path]
    destination_groups = [nsxt_policy_group.env_threat.path]
    action = "ALLOW"
    logged = false
    scope = [nsxt_policy_group.env_prod.path, nsxt_policy_group.env_threat.path]
  }
}

resource "nsxt_policy_security_policy" "dev_env" {
  display_name = "IDPS - Development Env."
  category = "Environment"
  locked = false
  stateful = true
  tcp_strict = false

  rule {
    display_name = "allow any to external"
    source_groups = [nsxt_policy_group.env_dev.path]
    destination_groups = [nsxt_policy_group.env_threat.path]
    action = "ALLOW"
    logged = false
    scope = [nsxt_policy_group.env_dev.path, nsxt_policy_group.env_threat.path]
  }
}

# Create DFW Rules for Applications
data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

resource "nsxt_policy_security_policy" "external" {
  display_name = "IDPS - External rules"
  category = "Application"
  locked = false
  stateful = true
  tcp_strict = false

  rule {
    display_name = "allow ssh"
    destination_groups = [nsxt_policy_group.env_threat.path]
    services = [data.nsxt_policy_service.ssh.path]
    action = "ALLOW"
    logged = false
    scope = [nsxt_policy_group.env_threat.path]
  }
  rule {
    display_name = "deny all"
    destination_groups = [nsxt_policy_group.env_threat.path]
    action = "DROP"
    logged = false
    scope = [nsxt_policy_group.env_threat.path]
  }
}
