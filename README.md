# Terraform GCP Setup
This Terraform configuration sets up a Virtual Private Cloud (VPC) and a subnet in Google Cloud Platform (GCP). It utilizes a modular approach, where the VPC setup is encapsulated in a separate module.

## Prerequisites

Before running this Terraform configuration, ensure you have the following prerequisites:

1. **Google Cloud Platform Account**: You need an active GCP account with appropriate permissions to create resources like VPCs and subnets.

2. **Google Cloud SDK (optional)**: It's recommended to have the Google Cloud SDK installed for authentication purposes. Refer to the [Google Cloud SDK installation guide](https://cloud.google.com/sdk/docs/install) for instructions.

3. **Terraform**: Install Terraform on your local machine. Refer to the [official Terraform documentation](https://learn.hashicorp.com/tutorials/terraform/install-cli) for installation instructions.

4. **Service Account Key**: You need a service account key with the necessary permissions to create resources on GCP. Download the JSON key file and keep it secure.

## Usage

### 1. Set up Google Cloud Authentication

If you haven't already configured authentication for Google Cloud, follow these steps:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/keyfile.json"
```
### 2. Clone the Repository and Initialize Terraform

```bash
git clone https://github.com/Basu-Patil/tf-gcp-infra
cd tf-gcp-infra
terraform init
```

### 3. Configure Terraform Variables
In the variables.tf file at root directory, adjust the variables according to your requirements. These may include project ID, region, subnet CIDR, etc.

### 4. Review and Apply Terraform Configuration
Review the Terraform execution plan to ensure it will create the resources as expected:
```bash
terraform plan
```

Once everything looks good, go ahead and apply the plan
```bash
terraform apply
```

### Module Structure
The VPC setup is encapsulated within a separate module located in the modules/vpc directory. This modular approach promotes reusability and maintainability.

### Files
main.tf: Main Terraform configuration file where the VPC module is called and the VPC and subnet and routes are created.
variables.tf: Defines input variables used by the Terraform configuration.
providers.tf: Defines the GCP(Google Cloud Platform) providers.
modules/vpc/: Directory containing the VPC module.


### Issue
google_service_networking_connection error: Cannot modify allocated ranges in CreateConnection. Please use UpdateConnection 

### Fix
gcloud beta services vpc-peerings update \
    --service=servicenetworking.googleapis.com \
    --ranges=private-ip-address \
    --network="web-application-vpc-2" \
    --project="casye6225-dev" \
    --force

### APIS

Cloud DNS API

