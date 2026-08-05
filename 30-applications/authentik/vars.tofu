
variable "users" {
    type = map(object({
      init_email = string
      enabled = bool

      # emitted on the profile scope, so OIDC apps can read it
      profile_claims = optional(object({
        immich_quota    = optional(number)
        nextcloud_quota = optional(string)
      }), {})
    }))

    validation {
      condition     = length(distinct([for u in var.users : lower(u.init_email)])) == length(var.users)
      error_message = "users init_email addresses must be unique."
    }
}

variable "groups" {
    type = map(object({
      is_superuser = bool
      users = list(string)
    }))
}
