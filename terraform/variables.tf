variable "cloud_id" {
  type    = string
  default        = "b1geka85su9shc2epst0"
  }

variable "folder_id" {
  type    = string
  default        = "b1gk501lkjc82415d2s5"
}

variable "default_zone" {
  type    = string
  default = "ru-central1-d"
  
}

variable ntc {
  type        = string
  default     = "terraform-create"
}

variable ssh_path_pub {
  type        = string
  default     = "~/.ssh/yc_key.pub"
}
variable auth_key {
  type        = string
  default     = "~/.auth_key.json"
}

