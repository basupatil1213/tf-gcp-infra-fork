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



# ssh firewall with varibles to block ssh login gcp
variable "ssh_firewall_name" {
  type = string
  default = "block-ssh-webapp"
}

variable "ssh_firewall_network" {
  type = string
  default = "web-application-vpc-2"
  
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
    all = {
      protocol = "all"
      ports = ["0-65535"]
    }
  }
}


variable "firewall_name" {
  type = string
  default = "allow-tcp-80-webapp"
}

variable "firewall_network" {
  type = string
  default = "web-application-vpc-2"
  
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
      ports = ["80","8080",22]
    }
  }
  
}

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
  default = "custom-image-success-cloud-2"
  
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

// map of variables for the metadata startup script
variable "metadata_startup_script" {
  type = object({
    mysql_port = string
    dialect = string
    port = string
  })
  default = {
    mysql_port = "3306"
    dialect = "mysql"
    port = "8080"
  }
}

// compute global address variable

variable "global_address_details" {
  type = object({
    name = string
    purpose = string
    address_type = string
    prefix_length = number
  })
  default = {
    
      name = "webapp-global-address-test"
      purpose = "VPC_PEERING"
      address_type = "INTERNAL"
      prefix_length = 16
    
}
}

// varible for google_sql_database_instance
// variable for google_sql_database_instance
variable "db_instance" {
  type = object({
    name = string
    region = string
    database_version = string
    deletion_protection = bool
    settings = object({
      disk_type = string
      tier = string
      availability_type = string
      disk_size = number
      ip_configuration = object({
        ipv4_enabled = bool
        enable_private_path_for_google_cloud_services = bool
      })
    })
    backup_configuration = object({
      enabled = bool
      binary_log_enabled = bool
    })
    password_validation_policy = object({
      enable_password_policy = bool
      min_length = number
      disallow_username_substring = bool
    })
  })
  default = {
    name = "webapp-database"
    region = "us-east1"
    database_version = "MYSQL_8_0"
    deletion_protection = false
    settings = {
      disk_type = "PD_SSD"
      tier = "db-f1-micro"
      availability_type = "REGIONAL"
      disk_size = 10
      ip_configuration = {
        ipv4_enabled = false
        enable_private_path_for_google_cloud_services = false
      }
    }
    backup_configuration = {
      enabled = true
      binary_log_enabled = true
    }
    password_validation_policy = {
      enable_password_policy = true
      min_length = 8
      disallow_username_substring = true
    }
  }
}

// varible for google_sql_database
variable "db_name" {
  type = string
  default = "web_app_db"
}

// varible for google_sql_user

variable "db_user_name" {
  type = string
  default = "webapp"
}