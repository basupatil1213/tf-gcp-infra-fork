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
  default = "custom-webapp-img"

}


variable "vpc_name" {
  type    = string
  default = "web-application-vpc-2"

}


variable "subnet_name" {
  type    = string
  default = "webapp"

}

variable "deletion_policy" {
  type    = string
  default = "ABANDON"

}

variable "vm_machine_type" {
  type    = string
  default = "custom-6-4096"

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

variable "mailgun_api_key" {
  type = string
}

variable "storage_bucket_name" {
  type    = string
  default = "basupatil-final-test"
}

variable "storage_object_name" {
  type    = string
  default = "Archive.zip"
}

variable "cloud_function_name" {
  type    = string
  default = "sendVerificationEmail"
}