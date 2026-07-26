variable "applications" {
    type = map(object({
      display_name = string

      type = string

      # Whether to hide it from the Authentik dashboard
      hidden = optional(bool, false)

      # Setting this creates a DNS entry pointing the hostname at the homelab:
      # _internal keys under <domain_lan>. _external keys under <domain>
      dns_hostname = optional(string)

      # Launch target on the Authentik dashboard. required unless hidden.
      href_url = optional(string)

      # Probe target for uptime monitoring. apps without one are not monitored.
      uptime_url = optional(string)

      allowed_users = optional(list(string), [])
      allowed_groups = optional(list(string), [])

      group = string
      policy_engine_mode = optional(string, "any")

      meta_description = optional(string, "")
      meta_publisher = optional(string, "")
      meta_icon = optional(string, "")
    }))

    validation {
      condition     = alltrue([for app in var.applications : contains(["forward-auth", "redirect"], app.type)])
      error_message = "applications[*].type must be either \"forward-auth\" or \"redirect\"."
    }

    validation {
      condition     = alltrue([for app in var.applications : app.hidden || app.href_url != null])
      error_message = "applications shown on the dashboard must set href_url."
    }

    validation {
      condition     = alltrue([for k, app in var.applications : endswith(k, "_internal") || endswith(k, "_external")])
      error_message = "application keys must end in _internal or _external."
    }

    validation {
      condition = alltrue([
        for k, app in var.applications : app.dns_hostname == null || (
          endswith(k, "_internal")
            ? endswith(app.dns_hostname, ".${local.generated.domain_lan}")
            : endswith(app.dns_hostname, ".${local.generated.domain}") && !endswith(app.dns_hostname, ".${local.generated.domain_lan}")
        )
      ])
      error_message = "dns_hostname must end in .<domain_lan> for _internal apps and .<domain> for _external apps."
    }
}
