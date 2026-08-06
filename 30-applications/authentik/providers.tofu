terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.5.0"
    }
  }
}

locals {
  values    = yamldecode(file("./values.enc.yaml"))
  generated = yamldecode(file("../../10-infra/generated/generated.infra.yaml"))
}

provider "authentik" {
  url   = "https://${local.applications["authentik_internal"].dns_hostname}"
  token = local.values.authentik.bootstrap_token
}