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
  apps    = module.apps.apps
  secrets      = sensitive(yamldecode(file("secrets.enc.yaml")))
}

provider "prowlarr" {
  url     = local.secrets.arr.prowlarr_url
  api_key = local.secrets.arr.prowlarr_api_key
}

provider "sonarr" {
  url     = local.secrets.arr.sonarr_url
  api_key = local.secrets.arr.sonarr_api_key
}

provider "radarr" {
  url     = local.secrets.arr.radarr_url
  api_key = local.secrets.arr.radarr_api_key
}
