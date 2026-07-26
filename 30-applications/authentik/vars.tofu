
variable "users" {
    type = map(object({
      init_email = string
      enabled = bool
    }))
}

variable "groups" {
    type = map(object({
      is_superuser = bool
      users = list(string)
    }))
}



# TODO: Optional parameters make the variables hard to read
variable "applications" {
    type = map(object({
      display_name = string

      type = string

      # Whether to show it on the Authentik dashboard
      hidden = optional(bool, false)

      # Whether it should be exposed to the open internet using Cloudflare Tunnels
      exposed = optional(bool, false)


      allowed_users = optional(list(string), [])
      allowed_groups = optional(list(string), [])

      external_host = string
      group = string
      policy_engine_mode = optional(string, "any")

      meta_description = string
      meta_publisher = string
      meta_icon = string
    }))

    validation {
      condition     = alltrue([for app in var.applications : contains(["proxy", "redirect"], app.type)])
      error_message = "applications[*].type must be either \"proxy\" or \"redirect\"."
    }
}