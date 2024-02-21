variable "project_id" {
  description = "The project ID to deploy into"
  type = string
}

variable "region" {
  description = "The region to deploy into"
  type = string
}

 // map of VPCs and subnets and related routes
variable "vpcs" {
  description = "The VPCs and subnets and related routes"
  type = map(object({
    vpc_name = string
    routing_mode = string
    auto_create_subnetworks = bool
    delete_default_routes_on_create = bool
    subnets = map(object({
      subnet_name = string
      ip_cidr_range = string
    }))
    routes = map(object({
      route_name = string
      dest_range = string
      next_hop_gateway = string
      route_tags = list(string)
      priority = number
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