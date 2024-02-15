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
