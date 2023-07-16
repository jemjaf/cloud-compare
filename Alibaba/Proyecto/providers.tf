terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "1.207.2"
    }
  }
}

provider "alicloud" {
  region = "us-east-1"
}