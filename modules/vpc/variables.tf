variable "project_id" {
    description = "The project ID to deploy into"
    type = string
}

variable "region" {
    description = "The region to deploy into"
    type = string
}


variable "vpc_name" {
    description = "The name of the VPC"
    type = string
}
variable "routing_mode" {
    description = "The routing mode for the VPC"
    type = string
}

variable "web_app_subnet_name" {
    description = "The name of the web application subnet"
    type = string
}
variable "web_app_subnet_ip_cidr_range" {
    description = "The IP CIDR range for the web application subnet"
    type = string
}

variable "db_subnet_name" {
    description = "The name of the database subnet"
    type = string
}
variable "db_subnet_ip_cidr_range" {
    description = "The IP CIDR range for the database subnet"
    type = string
}

variable "web_app_route" {
    description = "The IP CIDR range for the web application route"
    type = string
}

variable "auto_create_subnetworks" {
  description = "Whether to create subnetworks in the VPC"
  default = false
  type = bool
}

variable "delete_default_routes_on_create" {
  description = "Whether to delete the default route on create"
  default = true
  type = bool
}

variable "route_tags" {
  description = "The tags to apply to the route"
  type = list(string)
}

variable "next_hop_gateway" {
  description = "The next hop gateway for the route"
  type = string
}
