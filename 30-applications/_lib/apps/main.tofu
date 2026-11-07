# Aggregates all the app*.enc.yaml files under one roof and validates their schema

locals {
  root  = "${path.module}/../.."
  files = fileset(local.root, "**/app*.enc.yaml")
  infra = yamldecode(file("${local.root}/../10-infra/generated/generated.infra.yaml"))

  entries = [for f in local.files : yamldecode(file("${local.root}/${f}"))]
}

module "schema" {
  source     = "./schema"
  apps       = local.entries
  domain     = local.infra.domain
  domain_lan = local.infra.domain_lan
}

output "apps" {
  value = module.schema.apps
}
