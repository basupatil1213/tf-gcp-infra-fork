variable "project_id" {
  description = "The project ID to deploy into"
  type        = string
}
variable "region" {
  description = "The region to deploy into"
  type        = string
}

variable "vm_name" {
  type    = string
  default = "webapp"
}

variable "vm_zone" {
  type    = string
  default = "us-east1-b"

}

variable "vm_tags" {
  type    = list(string)
  default = ["webapp"]

}

variable "vm_image" {
  type    = string
  default = "custom-image-success-cloud-2"

}

variable "vm_machine_type" {
  type    = string
  default = "e2-micro"

}


variable "vm_boot_disk_mode" {
  type    = string
  default = "READ_WRITE"
}

variable "vm_boot_disk_size" {
  type    = number
  default = 20

}

variable "vm_boot_disk_type" {
  type    = string
  default = "pd-standard"
}

variable "network_tier" {
  type    = string
  default = "PREMIUM"
}


variable "firewall_name" {
  type    = string
  default = "allow-tcp-80-webapp"
}

variable "firewall_network" {
  type    = string
  default = "web-application-vpc-2"

}

variable "firwall_direction" {
  type    = string
  default = "INGRESS"

}

variable "firewall_source_ranges" {
  type    = list(string)
  default = ["0.0.0.0/0"]

}

variable "firewall_target_tags" {
  type    = list(string)
  default = ["webapp"]

}

variable "firewall_allowed_protocol" {
  type = map(object({
    protocol = string
    ports    = list(string)
    })
  )
  default = {
    tcp = {
      protocol = "tcp"
      ports    = ["80"]
    }
  }
}

variable "vpcs" {
  description = "The VPCs and subnets and related routes"
  type = map(object({
    vpc_name                        = string
    routing_mode                    = string
    auto_create_subnetworks         = bool
    delete_default_routes_on_create = bool
    subnets = map(object({
      subnet_name   = string
      ip_cidr_range = string
    }))
    routes = map(object({
      route_name       = string
      dest_range       = string
      next_hop_gateway = string
      route_tags       = list(string)
      priority         = number
    }))
  }))
}


# vm_instances = map(object({
#   vm_name = string
#   machine_type = string
#   zone = string
#   tags = list(string)
#   boot_disk = map(object({
#     initialize_params = map(string)
#   }))
# }))
# firewall_rules = map(object({
#   name = string
#   network = string
#   priority = number
#   direction = string
#   action = string
#   source_ranges = list(string)
#   target_tags = list(string)
#   allowed = list(object({
#     protocol = string
#     ports = list(string)
#   }))
# }))