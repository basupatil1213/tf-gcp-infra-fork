gcp_credentials_json = "../gcp-credentials/csye6225-413706-1b411ec942be.json"

gcp_project = "csye6225-413706"

gcp_region = "us-east1"

# vpc configuration
routing_mode = "REGIONAL"
vpc_name = "web-application-vpc"

# web app subnet configuration
web_app_subnet_name = "webapp"
web_app_subnet_ip_cidr_range = "10.0.0.0/24"

# db subnet configuration
db_subnet_name = "db"
db_subnet_ip_cidr_range = "10.0.1.0/24"

web_app_route = "0.0.0.0/0"
