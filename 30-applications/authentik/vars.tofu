

variable "state_passphrase" {
  type = string
}



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




variable "applications" {
    type = map(object({
      display_name = string

      type = string
      hidden = optional(bool, false)

      allowed_users = optional(list(string), [])
      allowed_groups = optional(list(string), [])

      external_host = string
      group = string
      policy_engine_mode = optional(string, "any")

      meta_description = string
      meta_publisher = string
      meta_icon = string
      meta_launch_url = string
    }))

    validation {
      condition     = alltrue([for app in var.applications : contains(["proxy", "redirect"], app.type)])
      error_message = "applications[*].type must be either \"proxy\" or \"redirect\"."
    }
}