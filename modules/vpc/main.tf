// Local variables to flatten the VPCs subnets and routes
locals {
    subnets = flatten([
    for vpc, vpc_config in var.vpcs : [
      for subnet, subnet_config in vpc_config.subnets : {
        vpc_name = vpc
        subnet_name = subnet
        subnet_config = subnet_config
      }
    ]
  ])
  routes = flatten([
    for vpc, vpc_config in var.vpcs : [
      for route, route_config in vpc_config.routes : {
        vpc_name = vpc
        route_name = route
        route_config = route_config
      }
    ]
  ])
}

resource "google_compute_network" "vpcs" {
  for_each = var.vpcs
  name = each.value.vpc_name
  project = var.project_id
  auto_create_subnetworks = each.value.auto_create_subnetworks
  routing_mode = each.value.routing_mode
  delete_default_routes_on_create = each.value.delete_default_routes_on_create
}

resource "google_compute_subnetwork" "subnet" {
  for_each = { for subnet in local.subnets : "${subnet.vpc_name}.${subnet.subnet_name}" => subnet }

  name          = each.value.subnet_config.subnet_name
  ip_cidr_range = each.value.subnet_config.ip_cidr_range
  network       = each.value.vpc_name
  depends_on = [ google_compute_network.vpcs ]

}

resource "google_compute_route" "route" {
  for_each = { for route in local.routes : "${route.vpc_name}.${route.route_name}" => route }

  name                   = each.value.route_config.route_name
  dest_range             = each.value.route_config.dest_range
  next_hop_gateway       = each.value.route_config.next_hop_gateway
  tags                   = each.value.route_config.route_tags
  priority               = each.value.route_config.priority
  network                = each.value.vpc_name
  depends_on = [ google_compute_network.vpcs ]
} 
//create compute instance
variable "vm_name" {
  type = string
  default = "webapp"
}

variable "vm_zone" {
  type = string
  default = "us-east1-b"
  
}

variable "vm_tags" {
  type = list(string)
  default = ["webapp"]
  
}

variable "vm_image" {
  type = string
  default = "custom-image-success-cloud"
  
}

variable "vm_machine_type" {
  type = string
  default = "e2-micro"
  
}

variable "vm_boot_disk_mode" {
  type = string
  default = "READ_WRITE"
}

variable "vm_boot_disk_size" {
  type = number
  default = 20
  
}

variable "vm_boot_disk_type" {
  type = string
  default = "pd-standard"
}

variable "network_tier" {
  type = string
  default = "PREMIUM"
}

resource "google_compute_instance" "name" {
  name = var.vm_name
  zone = var.vm_zone
  tags = var.vm_tags
  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = var.vm_boot_disk_size
      type  = var.vm_boot_disk_type
    }
    mode = var.vm_boot_disk_mode
  }
  machine_type = var.vm_machine_type
  network_interface {
    subnetwork = google_compute_subnetwork.subnet["web-application-vpc.webapp"].id
    access_config {
      network_tier = var.network_tier
    }
  }
}

variable "firewall_name" {
  type = string
  default = "allow-tcp-80-webapp"
}

variable "firewall_network" {
  type = string
  default = "web-application-vpc"
  
}

variable "firwall_direction" {
  type = string
  default = "INGRESS"
  
}

variable "firewall_source_ranges" {
  type = list(string)
  default = ["0.0.0.0/0"]
  
}

variable "firewall_target_tags" {
  type = list(string)
  default = ["webapp"]
  
}

variable "firewall_allowed_protocol" {
  type = map(object({
    protocol = string
    ports = list(string)
  })
  )
  default = {
    tcp = {
      protocol = "tcp"
      ports = ["80","8080"]
    }
  }
  
}

resource "google_compute_firewall" "allow-tcp-80-webapp" {
  name    = var.firewall_name
  network = var.firewall_network
  priority = 1000
  direction = var.firwall_direction
  source_ranges = var.firewall_source_ranges
  target_tags = var.firewall_target_tags
  allow {
    protocol = var.firewall_allowed_protocol.tcp.protocol
    ports = var.firewall_allowed_protocol.tcp.ports
  }
  depends_on = [ google_compute_network.vpcs ]
}

# ssh firewall with varibles to block ssh login gcp
variable "ssh_firewall_name" {
  type = string
  default = "allow-ssh-webapp"
}

variable "ssh_firewall_network" {
  type = string
  default = "web-application-vpc"
  
}

variable "ssh_firwall_direction" {
  type = string
  default = "INGRESS"
  
}

variable "ssh_firewall_source_ranges" {
  type = list(string)
  default = ["0.0.0.0/0"]
}

variable "ssh_firewall_target_tags" {
  type = list(string)
  default = ["webapp"]
}

variable "ssh_firewall_allowed_protocol" {
  type = map(object({
    protocol = string
    ports = list(string)
  })
  )
  default = {
    tcp = {
      protocol = "tcp"
      ports = ["22"]
    }
  }
}

# block ssh login
resource "google_compute_firewall" "block-ssh-webapp" {
  name    = var.ssh_firewall_name
  network = var.ssh_firewall_network
  priority = 1000
  direction = var.ssh_firwall_direction
  source_ranges = var.ssh_firewall_source_ranges
  target_tags = var.ssh_firewall_target_tags
  deny{
    protocol = var.ssh_firewall_allowed_protocol.tcp.protocol
    ports = var.ssh_firewall_allowed_protocol.tcp.ports
  }
  depends_on = [ google_compute_network.vpcs ]
}



# # create vm using cusomt image in webapp subnet
# resource "google_compute_instance" "webapp" {
#   for_each = { for vm in local.vm_instances : "${vm.vpc_name}.${vm.vm_name}" => vm }

#   name         = each.value.vm_config.vm_name
#   machine_type = each.value.vm_config.machine_type
#   zone         = each.value.vm_config.zone
#   tags         = each.value.vm_config.tags
#   boot_disk {
#     initialize_params {
#       image = each.value.vm_config.boot_disk.initialize_params.image 
#     }
#   }
#   network_interface {
#     subnetwork = google_compute_subnetwork.subnet["${each.value.vpc_name}.${each.value.vm_config.tags[0]}"].id
#   }
#   depends_on = [ google_compute_subnetwork.subnet ]
# }

# # create firewall rule to allow traffic to webapp from internet
# resource "google_compute_firewall" "allow-tcp-80-webapp" {
#   for_each = { for rule in local.firewall_rules : "${rule.vpc_name}.${rule.rule_name}" => rule }

#   name    = each.value.rule_config.name
#   network = each.value.rule_config.network
#   priority = each.value.rule_config.priority
#   direction = each.value.rule_config.direction
#   source_ranges = each.value.rule_config.source_ranges
#   target_tags = each.value.rule_config.target_tags
#   allow {
#     protocol = each.value.rule_config.allowed[0].protocol
#     ports = each.value.rule_config.allowed[0].ports
#   }
#   depends_on = [ google_compute_network.vpcs ]
# }