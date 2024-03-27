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

// service account for the webapp
resource "google_service_account" "webapp_service_account" {
  account_id = var.service_account_name
  display_name = var.service_account_display_name
  project = var.project_id
  create_ignore_already_exists = var.create_ignore_already_exists
}

resource "google_project_iam_binding" "webapp_service_account_iam_binding_logging_admin" {
  project = var.project_id
  role    = "roles/logging.admin"
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
}

resource "google_project_iam_binding" "webapp_service_account_iam_binding_monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
}

// IAM roles for pubsup topic message publisher

resource "google_project_iam_binding" "pubsub_topic_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
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
  machine_type =  var.vm_machine_type
  network_interface {
    subnetwork = google_compute_subnetwork.subnet["${var.vpc_name}.${var.subnet_name}"].id
    access_config {
      network_tier = var.network_tier
    }
  }
  metadata_startup_script = templatefile("modules/vpc/scripts/db-cred-setup.sh",{
    db_user = var.metadata_startup_script.db_user_name
    db_pass = random_password.db_password.result
    db_name = google_sql_database.webapp_database.name
    mysql_port = var.metadata_startup_script.mysql_port
    dialect = var.metadata_startup_script.dialect
    port = var.metadata_startup_script.port
    db_host = google_sql_database_instance.webapp_database.private_ip_address
  })

  service_account {
    email = google_service_account.webapp_service_account.email
    scopes = var.service_account_scopes
  }

  depends_on = [ google_service_account.webapp_service_account]
}

// get cloud dns managed zone

data "google_dns_managed_zone" "webapp_dns_zone" {
  name = var.dns_zone_name
  project = var.project_id
  
}

// create a record set for the webapp

resource "google_dns_record_set" "webapp_dns_record" {
  name = data.google_dns_managed_zone.webapp_dns_zone.dns_name
  managed_zone = data.google_dns_managed_zone.webapp_dns_zone.name
  type = var.dns_record_type
  ttl = var.dns_record_ttl
  rrdatas = [google_compute_instance.name.network_interface[0].access_config[0].nat_ip]
  depends_on = [ google_compute_instance.name ]
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
  network      = google_compute_network.vpcs[var.vpc_name].id
  prefix_length = var.global_address_details.prefix_length
}


resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta
  network                 = google_compute_network.vpcs[var.vpc_name].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  deletion_policy = var.deletion_policy
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
      private_network = google_compute_network.vpcs[var.vpc_name].id
      enable_private_path_for_google_cloud_services = var.db_instance.settings.ip_configuration.enable_private_path_for_google_cloud_services
    }
    tier = var.db_instance.settings.tier
    backup_configuration {
      enabled = var.db_instance.backup_configuration.enabled
      binary_log_enabled = var.db_instance.backup_configuration.binary_log_enabled
    
    }
  }
  depends_on = [ google_compute_network.vpcs, google_service_networking_connection.private_vpc_connection]
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
  host = "%" // google_compute_instance.name.network_interface[0].network_ip
  depends_on = [ google_sql_database_instance.webapp_database ]
}


variable "pubsub_topic_name" {
  type = string
  default = "verify_email"
}


// pubsub topic
resource "google_pubsub_topic" "topic" {
  name = var.pubsub_topic_name
}


// service account for the cloud function
resource "google_service_account" "account" {
  account_id = "gcf-sa"
  display_name = "Cloud Function Service Account"
}



// IAM roles for the service account for the cloud function



// get the storage bucket

variable "storage_bucket_name" {
  type = string
  default = "basupatil-final-test" // "webapp-storage-bucket"
}

data "google_storage_bucket" "bucket" {
  name = var.storage_bucket_name
}

// get the storage object

variable "storage_object_name" {
  type = string
  default = "Archive.zip"     //"webapp-storage-object"
}

data "google_storage_bucket_object" "object" {
  name = var.storage_object_name
  bucket = data.google_storage_bucket.bucket.name
  
}

// serverless vpc connector

resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpcs[var.vpc_name].id
  region =  var.region
}

// cloud function

variable "entry_point" {
  type = string
  default = "sendVerificationEmail"
  
}

variable "from_address" {
  type = string
  default = "noreply@basavarajpatil.me"
}

variable "domain_name" {
  type = string
  default = "basavarajpatil.me"
}

variable "mailgun_api_key" {
  type = string
}

variable "webapp_url" {
  type = string
  default = "basvarajpatil.me"
}

variable "cloud_function_name" {
  type = string
  default = "sendVerificationEmail"
  
}

resource "google_cloudfunctions2_function" "function" {
  name = var.cloud_function_name
  location = var.region
  description = "Cloud Function to send verification email"

  build_config {
    runtime = "nodejs20"
    entry_point = var.entry_point  # Set the entry point 
    source {
      storage_source {
        bucket = var.storage_bucket_name
        object = var.storage_object_name
      }

    }
    

    environment_variables = {
      MYSQL_HOST  = "${google_sql_database_instance.webapp_database.private_ip_address}"
      MYSQL_USER  = "${google_sql_user.mysql_db_user.name}"
      MYSQL_PASSWORD = "${random_password.db_password.result}"
      MYSQL_DATABASE = "${google_sql_database.webapp_database.name}"
      FROM_ADDRESS = "${var.from_address}"
      DOMAIN_NAME = "${var.domain_name}"
      MAILGUN_API_KEY = "${var.mailgun_api_key}"
    }
  }

  service_config {
    max_instance_count  = 1
    available_memory    = "256M"
    timeout_seconds     = 60
    ingress_settings = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    service_account_email = google_service_account.account.email
    vpc_connector = google_vpc_access_connector.connector.name
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
    environment_variables = {
      MYSQL_HOST  = "${google_sql_database_instance.webapp_database.private_ip_address}"
      MYSQL_USER  = "${google_sql_user.mysql_db_user.name}"
      MYSQL_PASSWORD = "${random_password.db_password.result}"
      MYSQL_DATABASE = "${google_sql_database.webapp_database.name}"
      FROM_ADDRESS = "${var.from_address}"
      DOMAIN_NAME = "${var.domain_name}"
      MAILGUN_API_KEY = "${var.mailgun_api_key}"
      WEBAPP_URL = "${var.webapp_url}"
    }

  }
  
  
  event_trigger {
    trigger_region = var.region
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = google_pubsub_topic.topic.id
    retry_policy = "RETRY_POLICY_RETRY"
  }

  depends_on = [ google_vpc_access_connector.connector, google_sql_database_instance.webapp_database, google_sql_database.webapp_database, google_sql_user.mysql_db_user, google_pubsub_topic.topic, google_service_account.account]
}

resource "google_cloudfunctions2_function_iam_member" "member" {
  project = google_cloudfunctions2_function.function.project
  cloud_function = google_cloudfunctions2_function.function.name
  role = "roles/cloudfunctions.invoker" // "roles/cloudfunctions.developer"
  member = "serviceAccount:${google_service_account.account.email}"
  depends_on = [ google_cloudfunctions2_function.function ]
}

