variable "apps" {
  type = list(object({
    name = string

    authentik = optional(object({
      name               = string
      group              = string
      meta_launch_url    = string
      meta_icon          = optional(string, "")
      meta_description   = optional(string, "")
      meta_publisher     = optional(string, "")
      policy_engine_mode = optional(string, "any")
      allowed_users      = optional(list(string), [])
      allowed_groups     = optional(list(string), [])

      # [forward-auth, oidc, bookmark]
      # for forward auth, it creates a proxy provider in Authentik.
      type = string

      # for type = "forward-auth": the proxy provider, in Authentik's field names
      forward_auth = optional(object({
        external_host   = string           # https://<host>, where Authentik sends the browser after login
        skip_path_regex = optional(string) # paths the proxy lets through unauthenticated
      }))

      # for type = "oidc"
      oidc = optional(object({
        client_id     = string
        client_secret = string
        issuer        = string
        client_type   = optional(string, "confidential")
        redirect_uris = list(object({
          url           = string
          matching_mode = optional(string, "strict")
        }))
        scopes = optional(list(string), ["openid", "email", "profile"])
        # groups claim rewrite. replace groups named <from> with <to>
        group_map                  = optional(list(object({ from = string, to = string })))
        grant_types                = optional(list(string), ["authorization_code", "refresh_token"])
        signing                    = optional(bool, true)
        sub_mode                   = optional(string)
        issuer_mode                = optional(string)
        include_claims_in_id_token = optional(bool)
        access_code_validity       = optional(string)
        access_token_validity      = optional(string)
        refresh_token_validity     = optional(string)
      }))

      # for type = "ldap"
      # the client pod also needs an ingress rule in authentik's NetworkPolicy
      ldap = optional(object({
        base_dn          = string
        bind_mode        = optional(string, "direct")
        search_mode      = optional(string, "direct")
        mfa_support      = optional(bool, true)
        certificate      = optional(bool, false)
        tls_server_name  = optional(string)
        uid_start_number = optional(number)
        gid_start_number = optional(number)
      }))
    }))

    # The hostnames the app answers on, read by the release template for its routes
    hosts = optional(list(string), [])

    # The hosts that get a public DNS record pointing at the proxy VPS
    public_vps_dns = optional(list(string), [])

    # Uptime Kuma monitors
    monitors = optional(list(object({
      name = string
      url  = string
    })), [])
  }))

  validation {
    condition     = alltrue([for app in var.apps : app.authentik == null || contains(["forward-auth", "bookmark", "oidc", "ldap"], app.authentik.type)])
    error_message = "authentik.type must be \"forward-auth\", \"bookmark\", \"oidc\" or \"ldap\"."
  }

  validation {
    condition     = alltrue([for app in var.apps : app.authentik == null || (app.authentik.type == "oidc") == (app.authentik.oidc != null)])
    error_message = "authentik.oidc must be set on, and only on, apps of type \"oidc\"."
  }

  validation {
    condition     = alltrue([for app in var.apps : app.authentik == null || (app.authentik.type == "ldap") == (app.authentik.ldap != null)])
    error_message = "authentik.ldap must be set on, and only on, apps of type \"ldap\"."
  }

  validation {
    condition     = alltrue([for app in var.apps : app.authentik == null || (app.authentik.type == "forward-auth") == (app.authentik.forward_auth != null)])
    error_message = "authentik.forward_auth must be set on, and only on, apps of type \"forward-auth\"."
  }


  validation {
    condition = alltrue([
      for app in var.apps : app.authentik == null || app.authentik.ldap == null || try(
        contains(["direct", "cached"], app.authentik.ldap.bind_mode) && contains(["direct", "cached"], app.authentik.ldap.search_mode),
      false)
    ])
    error_message = "ldap.bind_mode and ldap.search_mode must be \"direct\" or \"cached\"."
  }

  validation {
    condition     = alltrue([for app in var.apps : app.authentik == null || app.authentik.oidc == null || try(contains(["confidential", "public"], app.authentik.oidc.client_type), false)])
    error_message = "oidc.client_type must be \"confidential\" or \"public\"."
  }

  validation {
    condition = alltrue(flatten([
      for app in var.apps : app.authentik == null || app.authentik.oidc == null ? [] : [
        for r in app.authentik.oidc.redirect_uris : contains(["strict", "regex"], r.matching_mode)
      ]
    ]))
    error_message = "oidc.redirect_uris[*].matching_mode must be \"strict\" or \"regex\"."
  }


  validation {
    condition     = alltrue(flatten([for app in var.apps : [for h in app.hosts : endswith(h, ".${var.domain}")]]))
    error_message = "hosts must end in .<domain>."
  }

  validation {
    condition     = alltrue(flatten([for app in var.apps : [for h in app.public_vps_dns : contains(app.hosts, h)]]))
    error_message = "public_vps_dns must list hosts of the same entry."
  }

}
