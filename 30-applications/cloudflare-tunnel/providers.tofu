terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.22"
    }
  }
}


provider "cloudflare" {
  api_token = var.cloudflare_token
}