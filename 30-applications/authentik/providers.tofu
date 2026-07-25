terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.0"
    }
  }


  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    method "unencrypted" "migrate" {}
    
    state {
      method = method.aes_gcm.state
      fallback { method = method.unencrypted.migrate }
    }
    
    # state {
    #   method = method.unencrypted.migrate
    #   fallback { method = method.aes_gcm.state }
    # }
    plan {
      method = method.aes_gcm.state
    }
  }
}

locals {
  values    = yamldecode(file("./values.enc.yaml"))
  generated = yamldecode(file("../../10-infra/generated/generated.infra.yaml"))
}

provider "authentik" {
  url   = "https://authentik.${local.generated.domain_lan}"
  token = local.values.authentik.bootstrap_token
}