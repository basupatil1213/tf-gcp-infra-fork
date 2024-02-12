// GCP

provider "gcp" {
  credentials = file(vars.gcp_credentials_json)
  project     = vars.gcp_project
  region      = vars.gcp_region
}