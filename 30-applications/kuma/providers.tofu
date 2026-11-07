terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
  required_providers {
    uptimekuma = {
      source  = "breml/uptimekuma"
      version = "~> 0.4"
    }
  }
}

locals {
  apps = module.apps.apps
}

provider "uptimekuma" {
  endpoint = var.kuma_endpoint
  username = var.kuma_username
  password = var.kuma_password
}
