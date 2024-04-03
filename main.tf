module "vpcs" {
  source                     = "./modules/vpc"
  project_id                 = var.project_id
  region                     = var.region
  vpcs                       = var.vpcs
  vm_name                    = var.vm_name
  vm_zone                    = var.vm_zone
  vm_tags                    = var.vm_tags
  vm_image                   = var.vm_image
  vm_machine_type            = var.vm_machine_type
  vm_boot_disk_mode          = var.vm_boot_disk_mode
  vm_boot_disk_size          = var.vm_boot_disk_size
  vm_boot_disk_type          = var.vm_boot_disk_type
  network_tier               = var.network_tier
  firewall_name              = var.firewall_name
  firewall_network           = var.firewall_network
  firwall_direction          = var.firwall_direction
  firewall_source_ranges     = var.firewall_source_ranges
  firewall_target_tags       = var.firewall_target_tags
  vpc_name                   = var.vpc_name
  subnet_name                = var.subnet_name
  deletion_policy            = var.deletion_policy
  mailgun_api_key            = var.mailgun_api_key
  storage_bucket_name        = var.storage_bucket_name
  storage_object_name        = var.storage_object_name
  cloud_function_name        = var.cloud_function_name
  proxy_subnet_ip_cidr_range = var.proxy_subnet_ip_cidr_range
  certificate_path           = var.certificate_path
  private_key_path           = var.private_key_path
}


