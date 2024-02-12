resource "google_compute_network" "web-application-vpc" {
  name = var.vpc_name
  project = var.project_id
  auto_create_subnetworks = false
  routing_mode = var.routing_mode
}

// Web application subnet
resource "google_compute_subnetwork" "web-application-subnet" {
  name = var.web_app_subnet_name
  project = var.project_id
  region = var.region
  network = google_compute_network.web-application-vpc.self_link
  ip_cidr_range = var.web_app_subnet_ip_cidr_range
}

// database subnet
resource "google_compute_subnetwork" "database-subnet" {
  name = var.db_subnet_name
  project = var.project_id
  region = var.region
  network = google_compute_network.web-application-vpc.self_link
  ip_cidr_range = var.db_subnet_ip_cidr_range
}

// Web application route
resource "google_compute_route" "web-application-route" {
  name                   = "webapp-route"
  network                = google_compute_network.web-application-vpc.self_link
  dest_range             = var.web_app_route
  next_hop_gateway       = google_compute_network.web-application-vpc.gateway_ipv4
  priority               = 1999
  depends_on             = [google_compute_subnetwork.web-application-subnet]
}

