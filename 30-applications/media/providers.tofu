terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
  required_providers {
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "~> 3.2"
    }
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "~> 3.4"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "~> 2.4"
    }
  }
}

locals {
  applications = yamldecode(file("../app-registry/generated/generated.applications.yaml"))
}

provider "prowlarr" {
  url     = "https://${local.applications["prowlarr_internal"].dns_hostname}"
  api_key = var.prowlarr_api_key
}

provider "sonarr" {
  url     = "https://${local.applications["sonarr_internal"].dns_hostname}"
  api_key = var.sonarr_api_key
}

provider "radarr" {
  url     = "https://${local.applications["radarr_internal"].dns_hostname}"
  api_key = var.radarr_api_key
}
