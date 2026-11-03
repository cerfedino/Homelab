# Aggregates all the app*.enc.yaml files under one roof and validates their schema

locals {
  root  = "${path.module}/../.."
  files = fileset(local.root, "**/app*.enc.yaml")
  infra = yamldecode(file("${local.root}/../10-infra/generated/generated.infra.yaml"))

  entries = [for f in local.files : yamldecode(file("${local.root}/${f}"))]

  flat = flatten([
    for e in local.entries : [
      for variant, v in e : merge(v, { name = e.name, variant = variant }) if variant != "name"
    ]
  ])
}

module "schema" {
  source       = "./schema"
  applications = local.flat
  domain       = local.infra.domain
  domain_lan   = local.infra.domain_lan
}

output "applications" {
  value = module.schema.applications
  precondition {
    condition     = length(distinct(local.entries[*].name)) == length(local.entries)
    error_message = "an app name is declared in more than one app*.enc.yaml file."
  }
}

output "apps" {
  value = {
    for e in local.entries : e.name => {
      for variant, v in e : variant => module.schema.applications["${e.name}_${variant}"] if variant != "name"
    }
  }
}
