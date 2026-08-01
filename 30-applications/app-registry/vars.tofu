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

      # for type = "oidc"
      oidc = optional(object({
        client_id     = string
        client_secret = string
        client_type   = optional(string, "confidential")
        redirect_uris = list(object({
          url           = string
          matching_mode = optional(string, "strict")
        }))
        scopes                     = optional(list(string), ["openid", "email", "profile"])
        grant_types                = optional(list(string), ["authorization_code", "refresh_token"])
        signing                    = optional(bool, true)
        sub_mode                   = optional(string)
        issuer_mode                = optional(string)
        include_claims_in_id_token = optional(bool)
        access_code_validity       = optional(string)
        access_token_validity      = optional(string)
        refresh_token_validity     = optional(string)
      }))
    }))

    validation {
      condition     = alltrue([for app in var.applications : contains(["forward-auth", "bookmark", "oidc"], app.type)])
      error_message = "applications[*].type must be \"forward-auth\", \"bookmark\" or \"oidc\"."
    }

    validation {
      condition     = alltrue([for app in var.applications : (app.type == "oidc") == (app.oidc != null)])
      error_message = "the oidc attribute must be set on applications of type \"oidc\"."
    }

    validation {
      condition     = alltrue([for app in var.applications : app.oidc == null || try(contains(["confidential", "public"], app.oidc.client_type), false)])
      error_message = "oidc.client_type must be \"confidential\" or \"public\"."
    }

    validation {
      condition = alltrue(flatten([
        for app in var.applications : app.oidc == null ? [] : [
          for r in app.oidc.redirect_uris : contains(["strict", "regex"], r.matching_mode)
        ]
      ]))
      error_message = "oidc.redirect_uris[*].matching_mode must be \"strict\" or \"regex\"."
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
