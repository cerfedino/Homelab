terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
  }
}

locals {
  values    = yamldecode(file("./secrets.enc.yaml"))
  generated = yamldecode(file("../../10-infra/generated/generated.infra.yaml"))
}

provider "authentik" {
  url   = local.authentik_host
  token = local.values.authentik.bootstrap_token
}