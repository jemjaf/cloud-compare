terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.69.1"
    }
  }
}

provider "google" {
  project     = "playground-s-11-aebc9fa6"
  region      = "us-east1"
  zone        = "us-east1-b"
  credentials = "./SA_credentials.json"
}