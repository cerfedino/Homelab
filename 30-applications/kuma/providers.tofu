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
  apps = yamldecode(file("../app-registry/generated/generated.apps-summary.yaml")).apps
}

provider "uptimekuma" {
  endpoint = "https://${local.apps["kuma-api"].internal.dns_hostname}"
  username = var.kuma_username
  password = var.kuma_password
}
