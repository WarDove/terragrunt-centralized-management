variable "gha_oidc_enabled" {
  type    = bool
  default = false
}

variable "gha_role_name" {
  type        = string
  description = "Standard role name for GitHub Actions execution"
}

variable "tf_repo" {
  type = string
}

variable "app_repos" {
  type = set(string)
}