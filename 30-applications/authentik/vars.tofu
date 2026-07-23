

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