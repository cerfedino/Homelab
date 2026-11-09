variable "domain" {
  type = string
}

variable "domain_lan" {
  type = string
}

# keyed <name>_<variant>, the key each consumer root uses
output "applications" {
  value = {
    for app in var.applications : "${app.name}_${app.variant}" => { for k, v in app : k => v if k != "name" && k != "variant" }
  }
}
