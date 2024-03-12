variable "location" {
  type = string
}
variable "tre_id" {
  type = string
}

variable "ws_resource_group_name" {
  type = string
}

variable "tre_resource_id" {
  type = string
}

variable "ws_id" {
  type        = string
  description = "Dummy research workspace name"
  default = "ws-e7f6"
}

variable "short_workspace_id" {
  type = string
}
