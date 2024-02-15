module "application_vpc" {
  source = "./modules/vpc"
  vpc_name = var.vpc_name
  db_subnet_ip_cidr_range = var.db_subnet_ip_cidr_range
  db_subnet_name = var.db_subnet_name
  project_id = var.project_id
  region = var.region
  routing_mode = var.routing_mode
  web_app_route = var.web_app_route
  web_app_subnet_ip_cidr_range = var.web_app_subnet_ip_cidr_range
  web_app_subnet_name = var.web_app_subnet_name
  auto_create_subnetworks = var.auto_create_subnetworks
  delete_default_routes_on_create = var.delete_default_routes_on_create
  next_hop_gateway = var.next_hop_gateway
  route_tags = var.route_tags
}

