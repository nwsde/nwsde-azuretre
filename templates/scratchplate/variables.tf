variable "ws_id" {
  type        = string
  description = "Dummy research workspace name"
  default = "ws-AAAA"
}

variable "tre_id" {
  type        = string
  description = "Unique TRE ID"
  default = "111111111111"
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure location (region) for deployment of core TRE services"
}

variable "auth_tenant_id" {
  type        = string
  default     = "bcc87841-98cf-40e6-a2a0-f97e3dd7b7dd"
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}
variable "auth_client_id" {
  type        = string
  default     = "cfa6c94e-60b8-4e8f-b4c0-b15fd6da5801"
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}
variable "auth_client_secret" {
  type        = string
  default     =  "AUZ8Q~2D~iG_9o2P1q_jdhFt1xhJSvyVLTre1dzs"
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}

