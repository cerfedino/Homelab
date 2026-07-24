terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
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


provider "cloudflare" {
  api_token = var.cloudflare_token
}