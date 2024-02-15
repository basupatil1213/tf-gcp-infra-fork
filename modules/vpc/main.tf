resource "google_compute_network" "web-application-vpc" {
  name = var.vpc_name
  project = var.project_id
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode = var.routing_mode
  delete_default_routes_on_create = var.delete_default_routes_on_create
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


resource "google_compute_route" "web-application-route" {
  name        = "webapp-route"
  network     = google_compute_network.web-application-vpc.self_link
  dest_range  = var.web_app_route
  next_hop_gateway = var.next_hop_gateway
  priority    = 1000
  tags = var.route_tags
  
}