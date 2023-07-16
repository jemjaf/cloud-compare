terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.69.1"
    }
  }
}

provider "google" {
  project     = local.service_account.project_id
  region      = "us-east1"
  zone        = local.zone
  credentials = "./SA_credentials.json"
}