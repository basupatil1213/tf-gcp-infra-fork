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

// crypto encrypter decrypter role for the service account

variable "encrypter_decrypter_role" {
  type = string
  default = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  
}

// compute engine service agent role for the service account

variable "gce_service_agent_email" {
  type = string
  default = "service-586858243800@compute-system.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.vm_crypto_key.id
  role          = var.encrypter_decrypter_role

  members = [
    "serviceAccount:${var.gce_service_agent_email}",
  ]
}


// IAM roles for the service account

variable "webapp_loggin_role" {
  type = string
  default = "roles/logging.admin"
  
}

resource "google_project_iam_binding" "webapp_service_account_iam_binding_logging_admin" {
  project = var.project_id
  role    = var.webapp_loggin_role
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
}

// monitoring metric writer role

variable "monitoring_metric_writer_role" {
  type = string
  default = "roles/monitoring.metricWriter"
  
}

resource "google_project_iam_binding" "webapp_service_account_iam_binding_monitoring_metric_writer" {
  project = var.project_id
  role    = var.monitoring_metric_writer_role
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
}

// IAM roles for pubsup topic message publisher

variable "pubsub_topic_publisher_role" {
  type = string
  default = "roles/pubsub.publisher"
  
}

resource "google_project_iam_binding" "pubsub_topic_publisher" {
  project = var.project_id
  role    = var.pubsub_topic_publisher_role
  members = ["serviceAccount:${google_service_account.webapp_service_account.email}"]
  depends_on = [ google_service_account.webapp_service_account ]
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
  rrdatas = [google_compute_address.lb_private_ip_alloc.address]
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
  priority = 1001
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
  
  encryption_key_name = google_kms_crypto_key.sql_crypto_key.id
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
  host = "%"
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

# data "google_storage_bucket" "bucket" {
#   name = var.storage_bucket_name
# }

// get the storage object

// rotaion period for the key

variable "rotation_period" {
  type = string
  default = "2592000s"
}

# Create a CMEK for Cloud Storage Buckets
resource "google_kms_crypto_key" "storage_bucket_crypto_key" {
  name            = "storage-crypto-key"
  key_ring        = google_kms_key_ring.webapp_key_ring.id
  rotation_period = var.rotation_period # 30 days
   lifecycle {
    prevent_destroy = false
  }
  depends_on = [ google_kms_key_ring.webapp_key_ring ]
}

data "google_storage_project_service_account" "gcs_account" {}

# Grant permission to the service account to use the Cloud KMS key
resource "google_kms_crypto_key_iam_binding" "binding" {
  crypto_key_id = google_kms_crypto_key.storage_bucket_crypto_key.id
  role          = var.encrypter_decrypter_role
  members       = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

# Create the Cloud Storage bucket with encryption enabled using the Cloud KMS key

// storage class

variable "storage_class" {
  type = string
  default = "STANDARD"
}

resource "google_storage_bucket" "function_code_buckets" {
  name     = var.storage_bucket_name
  location = var.region
  storage_class = var.storage_class

  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_bucket_crypto_key.id
  }
}

# Upload an object to the Cloud Storage bucket

variable "storage_object_name" {
  type = string
  default = "Archive.zip"     //"webapp-storage-object"
}

variable "storage_object_source" {
  type = string
  default = "/Users/basavarajpatil/Developer/csye6225/tf-gcp-infra-fork/modules/vpc/Archive.zip"
  
}
resource "google_storage_bucket_object" "object" {
  name   = var.storage_object_name
  bucket = google_storage_bucket.function_code_buckets.name
  source = var.storage_object_source
  depends_on = [ google_storage_bucket.function_code_buckets ]
}



# data "google_storage_bucket_object" "object" {
#   name = var.storage_object_name
#   bucket = data.google_storage_bucket.bucket.name
  
# }

// serverless vpc connector

variable "vpc_access_ip_range" {
  type = string
  default = "10.8.0.0/28"
}

variable "min_instances" {
  type = number
  default = 2
  
}

variable "max_instances" {
  type = number
  default = 3
}

resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  ip_cidr_range = var.vpc_access_ip_range
  network       = google_compute_network.vpcs[var.vpc_name].id
  region =  var.region
  max_instances = var.max_instances
  min_instances = var.min_instances
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
  default = "cf-send-verification-email"
  
}

// run time

variable "runtime" {
  type = string
  default = "nodejs20"
}

// service config variables

// 1. max_instance_count

variable "max_instance_count" {
  type = number
  default = 1
  
}

// 2. available_memory

variable "available_memory" {
  type = string
  default = "256M"
  
}

// 3. timeout_seconds

variable "timeout_seconds" {
  type = number
  default = 60
  
}

// 4. ingress_settings

variable "ingress_settings" {
  type = string
  default = "ALLOW_ALL"
  
}
// 5. all_traffic_on_latest_revision

variable "all_traffic_on_latest_revision" {
  type = bool
  default = true
  
}
// 6. egrees_settings

variable "egress_settings" {
  type = string
  default = "PRIVATE_RANGES_ONLY"
  
}

// event trigger variables

// 2. event_type

variable "event_type" {
  type = string
  default = "google.cloud.pubsub.topic.v1.messagePublished"
  
}

// 4. retry_policy

variable "retry_policy" {
  type = string
  default = "RETRY_POLICY_RETRY"
  
}

resource "google_cloudfunctions2_function" "function" {
  name = var.cloud_function_name
  location = var.region
  description = "Cloud Function to send verification email"

  build_config {
    runtime = var.runtime
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
    max_instance_count  = var.max_instance_count
    available_memory    = var.available_memory
    timeout_seconds     = var.timeout_seconds
    ingress_settings = var.ingress_settings
    all_traffic_on_latest_revision = var.all_traffic_on_latest_revision
    service_account_email = google_service_account.account.email
    vpc_connector = google_vpc_access_connector.connector.name
    vpc_connector_egress_settings = var.egress_settings
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
    event_type = var.event_type
    pubsub_topic = google_pubsub_topic.topic.id
    retry_policy = var.retry_policy
  }

  depends_on = [ google_vpc_access_connector.connector, google_sql_database_instance.webapp_database, google_sql_database.webapp_database, google_sql_user.mysql_db_user, google_pubsub_topic.topic, google_service_account.account, google_storage_bucket.function_code_buckets, google_storage_bucket_object.object]
}

// cloud function role

variable "cloud_function_role" {
  type = string
  default = "roles/cloudfunctions.developer"
  
}

resource "google_cloudfunctions2_function_iam_member" "member" {
  project = google_cloudfunctions2_function.function.project
  cloud_function = google_cloudfunctions2_function.function.name
  role = var.cloud_function_role
  member = "serviceAccount:${google_service_account.account.email}"
  depends_on = [ google_cloudfunctions2_function.function ]
}

// google compute instance template

variable "instance_template_name" {
  type = string
  default = "webapp-ce-temp"
  
}

variable "template_tags" {
  type = list(string)
  default = ["webapp"]
}

variable "can_ip_forward" {
  type = bool
  default = false
  
}

variable "automated_restart" {
  type = bool
  default = true
  
}

variable "on_host_maintenance" {
  type = string
  default = "MIGRATE"
  
}

// disk related variables

variable "disk_auto_delete" {
  type = bool
  default = true
  
}

variable "disk_boot" {
  type = bool
  default = true
  
}

resource "google_compute_region_instance_template" "webapp_ce_temp" {
  name = var.instance_template_name
  description = "Webapp Compute Engine Instance Template"
  tags = var.template_tags
  instance_description = "Webapp Compute Engine Instance"
  machine_type = var.vm_machine_type
  can_ip_forward = var.can_ip_forward
  scheduling {
    automatic_restart   = var.automated_restart
    on_host_maintenance = var.on_host_maintenance
  }

  disk {
    source_image      = var.vm_image
    auto_delete       = var.disk_auto_delete
    boot              = var.disk_boot

    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_crypto_key.id
    }
  }

  network_interface {
    network = google_compute_network.vpcs[var.vpc_name].id
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
    pubsub_url = "projects/${var.project_id}/topics/${var.pubsub_topic_name}"
  })

  service_account {
    email = google_service_account.webapp_service_account.email
    scopes = var.service_account_scopes
  }
  depends_on = [ google_kms_crypto_key_iam_binding.crypto_key ]
}

// 
// service-586858243800@compute-system.iam.gserviceaccount.com



// health check for the instance group

variable "health_check_path" {
  type = string
  default = "/healthz"
  
}

variable "health_check_port" {
  type = string
  default = "8080"
  
}
resource "google_compute_region_health_check" "webapp_health_check" {
  name = "webapp-health-check"
  check_interval_sec = 10
  timeout_sec = 10
  healthy_threshold = 10
  unhealthy_threshold = 10
  http_health_check {
    request_path = var.health_check_path
    port         = var.health_check_port
  }
  region = var.region
}

// google compute instance group manager

variable "distribution_policy_zones" {
  type = list(string)
  default = ["us-west1-a", "us-west1-b"]
  
}

resource "google_compute_region_instance_group_manager" "webappigm" {
  name = "webappigm"

  base_instance_name         = "webapp-instance"
  region                     = var.region
  distribution_policy_zones  = var.distribution_policy_zones

  version {
    instance_template = google_compute_region_instance_template.webapp_ce_temp.self_link
  }

  all_instances_config {
    
  }

  named_port {
    name = "webapp-port"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_region_health_check.webapp_health_check.id
    initial_delay_sec = 300
  }
}


// autoscaler for the instance group

variable "target_utilization" {
  type = number
  default = 0.05
  
}

variable "max_replicas" {
  type = number
  default = 6
  
}

variable "min_replicas" {
  type = number
  default = 2
  
}

variable "cooldown_period" {
  type = number
  default = 60
  
}

resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name = "webapp-autoscaler"
  target = google_compute_region_instance_group_manager.webappigm.id
  region = var.region
  autoscaling_policy {
    max_replicas = var.max_replicas
    min_replicas = var.min_replicas
    cooldown_period = var.cooldown_period
    cpu_utilization {
      target = var.target_utilization
    }
  }
}

// proxy subnet for load balancer

variable "proxy_subnet_ip_cidr_range" {
  type = string
}
resource "google_compute_subnetwork" "proxy_only" {
  name          = "proxy-only-subnet"
  ip_cidr_range = var.proxy_subnet_ip_cidr_range
  network       = google_compute_network.vpcs[var.vpc_name].id
  purpose       = "REGIONAL_MANAGED_PROXY"
  region        = var.region
  role          = "ACTIVE"
}

// backend service for the load balancer

resource "google_compute_region_backend_service" "webapp_backend_service" {
  name = "webapp-backend-service"
  protocol = "HTTP"
  session_affinity      = "NONE"
  timeout_sec = 60
  port_name = "webapp-port"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks = [google_compute_region_health_check.webapp_health_check.id]
  region = var.region
  backend {
    group = google_compute_region_instance_group_manager.webappigm.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  
}


// url map for the load balancer

resource "google_compute_region_url_map" "webapp_url_map" {
  name = "webapp-url-map"
  default_service = google_compute_region_backend_service.webapp_backend_service.id
  region = var.region
  # host_rule {
  #   hosts = ["*"]
  #   path_matcher = "allpaths"
  # }
  # path_matcher {
  #   name = "allpaths"
  #   default_service = google_compute_region_backend_service.webapp_backend_service.id
  #   path_rule {
  #     paths = ["/*"]
  #     service = google_compute_region_backend_service.webapp_backend_service.id
  #   }
  # }
}

// target http proxy for the load balancer

# resource "google_compute_region_target_http_proxy" "webapp_target_http_proxy" {
#   name = "webapp-target-http-proxy"
#   url_map = google_compute_region_url_map.webapp_url_map.id
#   region = var.region
# }

// target https proxy for the load balancer

resource "google_compute_region_target_https_proxy" "webapp_target_https_proxy" {
  name = "webapp-target-https-proxy"
  url_map = google_compute_region_url_map.webapp_url_map.id
  ssl_certificates = [google_compute_region_ssl_certificate.webapp_ssl_cert.id]
  region = var.region
}

variable "certificate_path" {
  type = string
}

variable "private_key_path" {
  type = string
}

resource "google_compute_region_ssl_certificate" "webapp_ssl_cert" {
  name = "webapp-ssl-cert"
  private_key = file(var.private_key_path)
  certificate = file(var.certificate_path)
  region = var.region
}



// reserved ip address for the load balancer

resource "google_compute_address" "lb_private_ip_alloc" {
  name = "webapp-private-ip-alloc"
  address_type = "EXTERNAL"
  region = var.region
  network_tier = var.network_tier
}


// forwarding rule for the load balancer

variable "load_balancing_scheme" {
  type = string
  default = "EXTERNAL_MANAGED"
  
}

variable "lb_port_range" {
  type = string
  default = "443"
  
}

variable "lb_port_protocol" {
  type = string
  default = "TCP"
  
}

variable "lb_network_tier" {
  type = string
  default = "STANDARD"
  
}

resource "google_compute_forwarding_rule" "webapp_forwarding_rule" {
  name = "webapp-forwarding-rule"
  provider = google-beta
  region = var.region
  target = google_compute_region_target_https_proxy.webapp_target_https_proxy.id
  # target = google_compute_region_target_http_proxy.webapp_target_http_proxy.id
  load_balancing_scheme = var.load_balancing_scheme
  ip_address = google_compute_address.lb_private_ip_alloc.id
  port_range = var.lb_port_range
  ip_protocol = var.lb_port_protocol
  depends_on = [ google_compute_subnetwork.proxy_only ]
  project = var.project_id
  network_tier = var.lb_network_tier
  network = google_compute_network.vpcs[var.vpc_name].id
}

// firewall rule for the load balancer

variable "firewall_port" {
  type = list(string)
  default = ["8080"]
  
}

variable "as_firewall_source_ranges" {
  type = list(string)
  default = ["130.211.0.0/22", "35.191.0.0/16"]
  
}

variable "target_tags" {
  type = list(string)
  default = ["webapp"]
  
}

resource "google_compute_firewall" "default" {
  name = "fw-allow-health-check"
  allow {
    protocol = var.lb_port_protocol
    ports = var.firewall_port
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpcs[var.vpc_name].id
  priority      = 666
  source_ranges = var.as_firewall_source_ranges
  target_tags   = var.target_tags
}


resource "google_compute_firewall" "allow_proxy" {
  name = "fw-allow-proxies"
  allow {
    ports    = var.firewall_port
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpcs[var.vpc_name].id
  priority      = 666
  source_ranges = [var.proxy_subnet_ip_cidr_range]
  target_tags   = var.target_tags
}

// key ring for the cloud kms

variable "key_ring_name" {
  type = string
  
}
resource "google_kms_key_ring" "webapp_key_ring" {
  name     = var.key_ring_name
  location = var.region
  project = var.project_id
  lifecycle {
    prevent_destroy = false
  }
}

// crypto key for the cloud kms

//purpose

variable "crypto_key_purpose" {
  type = string
  default = "ENCRYPT_DECRYPT"
  
}

//retention period for 30 days

# variable "rotation_period" {
#   type = string
#   default = "2592000s"
  
# }



// vm crypto key

variable "vm_crypto_key_name" {
  type = string
  default = "webapp-vm-crypto-key-1"
  
}



resource "google_kms_crypto_key" "vm_crypto_key" {
  name     = var.vm_crypto_key_name
  key_ring = google_kms_key_ring.webapp_key_ring.id
  purpose  = var.crypto_key_purpose
  rotation_period = var.rotation_period
  lifecycle {
    prevent_destroy = false
  }
}

// cloud sql crypto key

variable "sql_crypto_key_name" {
  type = string
  default = "webapp-sql-crypto-key-1"
  
}

resource "google_kms_crypto_key" "sql_crypto_key" {
  name     = var.sql_crypto_key_name
  key_ring = google_kms_key_ring.webapp_key_ring.id
  purpose  = var.crypto_key_purpose
  rotation_period = var.rotation_period
  lifecycle {
    prevent_destroy = false
  }
}


// cloud sql service account

variable "cloud_sql_service" {
  type = string
  default = "sqladmin.googleapis.com"
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = var.cloud_sql_service
  project = var.project_id
}

// cloud sql crypto key iam binding

variable "cloud_sql_crypto_key_iam_binding_role" {
  type = string
  default = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  
}
resource "google_kms_crypto_key_iam_binding" "cloud_sql_crypto_key_iam_binding" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.sql_crypto_key.id
  role          = var.cloud_sql_crypto_key_iam_binding_role

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
  ]
}


// cloud storage crypto key

# variable "storage_crypto_key_name" {
#   type = string
#   default = "webapp-storage-crypto-key-1"
  
# }

# resource "google_kms_crypto_key" "storage_crypto_key" {
#   name     = var.storage_crypto_key_name
#   key_ring = google_kms_key_ring.webapp_key_ring.id
#   purpose  = var.crypto_key_purpose
#   rotation_period = var.rotation_period
#   lifecycle {
#     prevent_destroy = false
#   }
# }

// update the bucket with the crypto key

# resource "google_storage_bucket" "cloud_function_bucket"{
#   name = var.storage_bucket_name
#   location = var.region
#   project = var.project_id
#   encryption {
#     default_kms_key_name = google_kms_crypto_key.storage_crypto_key.name
#   }
# }




// regional load balancer



// ssl certificate for the load balancer

# resource "tls_private_key" "private_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

# resource "tls_self_signed_cert" "self_sign_cert" {
#   # key_algorithm   = tls_private_key.default.algorithm
#   private_key_pem = tls_private_key.private_key.private_key_pem
#   subject {
#     common_name  = "basavarajpatil.me"
#     organization = "Production"
#   }

#   validity_period_hours = 400

#   allowed_uses = [
#     "key_encipherment",
#     "digital_signature",
#     "server_auth",
#   ]
# }

# resource "google_compute_region_ssl_certificate" "gce_lb_cert" {
#   name        = "gce-lb-cert"
#   project     = var.project_id
#   private_key = tls_private_key.private_key.private_key_pem
#   certificate = tls_self_signed_cert.self_sign_cert.cert_pem
# }

// global load balancer from gcp

# variable service_port{
#   type = number
#   default = 8080

# }

# variable service_port_name{
#   type = string
#   default = "webapp-port"
# }


# module "gce-lb-http" {
#   source            = "GoogleCloudPlatform/lb-http/google"
#   version           = "~> 9.0"

#   project           = var.project_id
#   name              = "group-https-lb"
#   target_tags       = ["webapp"]
#   network = google_compute_network.vpcs[var.vpc_name].id
#   backends = {
#     default = {
#       port                            = var.service_port
#       protocol                        = "HTTP"
#       port_name                       = var.service_port_name
#       timeout_sec                     = 10
#       enable_cdn                      = false


#       health_check = {
#         request_path        = "/healthz"
#         port                = var.service_port
#       }

#       log_config = {
#         enable = false
#         sample_rate = 1.0
#       }

#       groups = [
#         {
#           # Each node pool instance group should be added to the backend.
#           group                        = google_compute_region_instance_group_manager.webappigm.instance_group
#         },
#       ]

#       iap_config = {
#         enable               = false
#       }
#     }
#   }
# }




