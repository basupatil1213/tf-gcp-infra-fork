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
  private_ip_google_access = true

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
    subnetwork = google_compute_subnetwork.subnet["web-application-vpc-2.webapp"].id
    access_config {
      network_tier = var.network_tier
    }
  }
  metadata_startup_script = templatefile("modules/vpc/scripts/db-cred-setup.sh",{
    db_user = google_sql_user.mysql_db_user.name
    db_pass = random_password.db_password.result
    db_name = google_sql_database.webapp_database.name
    mysql_port = var.metadata_startup_script.mysql_port
    dialect = var.metadata_startup_script.dialect
    port = var.metadata_startup_script.port
    db_host = google_sql_database_instance.webapp_database.private_ip_address
  })
}


resource "google_compute_firewall" "allow-tcp-80-webapp" {
  name    = var.firewall_name
  network = var.firewall_network
  priority = 999
  direction = var.firwall_direction
  source_ranges = var.firewall_source_ranges
  target_tags = var.firewall_target_tags
  allow {
    protocol = var.firewall_allowed_protocol.tcp.protocol
    ports = var.firewall_allowed_protocol.tcp.ports
  }
  depends_on = [ google_compute_network.vpcs ]
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
    protocol = var.ssh_firewall_allowed_protocol.all.protocol
  }
  depends_on = [ google_compute_network.vpcs ]
}


# compute_internal_ip_private_access
resource "google_compute_global_address" "private_ip_alloc" {
  provider     = google-beta
  project      = var.project_id
  name         = var.global_address_details.name
  address_type = var.global_address_details.address_type
  purpose      = var.global_address_details.purpose
  network      = google_compute_network.vpcs["web-application-vpc-2"].id
  prefix_length = var.global_address_details.prefix_length
}


resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta
  network                 = google_compute_network.vpcs["web-application-vpc-2"].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  deletion_policy = "ABANDON"
  # depends_on = [ google_compute_global_address.private_ip_connection ]
}

resource "google_sql_database_instance" "webapp_database" {
  name = var.db_instance.name
  database_version = var.db_instance.database_version
  region = var.db_instance.region
  deletion_protection = var.db_instance.deletion_protection
  settings {
    disk_type = var.db_instance.settings.disk_type
    availability_type = var.db_instance.settings.availability_type
    disk_size = var.db_instance.settings.disk_size
    ip_configuration {
      ipv4_enabled = var.db_instance.settings.ip_configuration.ipv4_enabled
      private_network = google_compute_network.vpcs["web-application-vpc-2"].id
      enable_private_path_for_google_cloud_services = var.db_instance.settings.ip_configuration.enable_private_path_for_google_cloud_services
    }
    tier = var.db_instance.settings.tier
    backup_configuration {
      enabled = var.db_instance.backup_configuration.enabled
      binary_log_enabled = var.db_instance.backup_configuration.binary_log_enabled
    
    }
  }
  depends_on = [ google_compute_network.vpcs["web-application-vpc-2"], google_service_networking_connection.private_vpc_connection]
}

// CLoudSQL Database instance

resource "google_sql_database" "webapp_database" {
  name = var.db_name
  instance = google_sql_database_instance.webapp_database.name
  project = var.project_id
  depends_on = [ google_sql_database_instance.webapp_database, random_password.db_password ]

}

// random password generator
resource "random_password" "db_password" {
  length = 8
  special = false
}

//sql username

resource "google_sql_user" "mysql_db_user" {
  name = var.db_user_name
  instance = google_sql_database_instance.webapp_database.name
  password = random_password.db_password.result
  project = var.project_id
  depends_on = [ google_sql_database_instance.webapp_database ]
}
