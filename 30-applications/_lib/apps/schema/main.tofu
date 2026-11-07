variable "domain" {
  type = string
}

variable "domain_lan" {
  type = string
}

locals {
  hosts = flatten(var.apps[*].hosts)
}

output "apps" {
  value = { for app in var.apps : app.name => app }

  precondition {
    condition     = length(distinct(var.apps[*].name)) == length(var.apps)
    error_message = "an app name is declared in more than one app*.enc.yaml file."
  }

  precondition {
    condition     = length(distinct(local.hosts)) == length(local.hosts)
    error_message = "a host is declared in more than one app*.enc.yaml file."
  }
}
