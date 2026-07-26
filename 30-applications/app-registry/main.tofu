terraform {
  backend "local" {
    path = "terraform.enc.tfstate"
  }
}

locals {
  generated = yamldecode(file("../../10-infra/generated/generated.infra.yaml"))
}
