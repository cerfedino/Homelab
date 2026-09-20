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
  secrets      = sensitive(yamldecode(file("values.enc.yaml")))
}

provider "prowlarr" {
  url     = "https://${local.applications["prowlarr_internal"].dns_hostname}"
  api_key = local.secrets.arr.prowlarr_api_key
}

provider "sonarr" {
  url     = "https://${local.applications["sonarr_internal"].dns_hostname}"
  api_key = local.secrets.arr.sonarr_api_key
}

provider "radarr" {
  url     = "https://${local.applications["radarr_internal"].dns_hostname}"
  api_key = local.secrets.arr.radarr_api_key
}
