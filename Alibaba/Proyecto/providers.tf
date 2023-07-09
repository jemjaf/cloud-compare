terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "1.207.2"
    }
  }
}

provider "alicloud" {
  access_key = "LTAI5t8mxhre3jcnWhGbbVgf"
  secret_key = "jfNX1iYYR3zE32bAbJJ872md37jrFR"
  region     = "us-east-1"
}