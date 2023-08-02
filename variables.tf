# ================================================================== runners ===

variable "github_app_secrets" {
  type = object({
    id  = string
    key = string
  })
  description = "Object containing `id` and `key` for the GitHub app."
}

variable "github_app_webhook_password" {
  type        = string
  description = "Password for the GitHub app webhook. An empty string implies a randomly generated password."
  default     = ""
}

variable "github_organization" {
  type        = string
  description = "Name of the GitHub organization."
}

variable "github_organization_runner_enabled" {
  type        = bool
  description = "Toggle to activate runners for all projects in the organization."
  default     = true
}

variable "runner_ephemeral_mode_enabled" {
  type        = bool
  description = "Toggle to activate ephemeral runners."
  default     = false
}

variable "runner_version" {
  type        = string
  description = "Version of the GitHub Action runner."
}

variable "runner_os" {
  type        = string
  description = "Operating system for the GitHub Action runner."
  default     = "linux"
}

variable "runner_pool_config" {
  type = list(object({
    cron  = string
    tz    = optional(string, "America/New_York")
    count = number
  }))
  description = "List of time periods (cron expressions) to maintain a pool of warm runners."
  default     = []
}

variable "runner_min_running_time" {
  type        = number
  description = "Minimum runtime (in minutes) for an EC2 action runner before termination if idle."
  default     = 15
}

variable "runner_maximum_count" {
  type        = number
  description = "Maximum number of EC2 action runners."
  default     = 10
}

variable "runner_labels" {
  type        = list(string)
  description = "Additional labels for the GitHub Action runners."
  default     = []
}

# ----------------------------------------------------------------- instance ---

variable "docker_logins" {
  type = list(object({
    user   = string
    pass   = string
    server = optional(string, "https://index.docker.io/v1/")
  }))
  description = "List of Docker auth credentials for Secrets Manager."
  default     = []
}

# ----------------------------------------------------------------- instance ---

variable "instance_ami_name" {
  type        = string
  description = "Name of the Amazon Machine Image (AMI) for the GitHub Action runner."
  default     = "al2023-ami-2023.*-kernel-*-x86_64"
}

variable "instance_types" {
  type        = set(string)
  description = "Set of instance types for the action runner."
  default     = ["m5ad.large", "m5d.large"]
}

variable "instance_lifecycle_type" {
  type        = string
  description = "Lifecycle type for action runner instances. Options: `spot` or `on-demand`."

  validation {
    condition     = contains(["spot", "on-demand"], lower(var.instance_lifecycle_type))
    error_message = "Instance lifecycle type must be either `spot` or `on-demand`."
  }
}

# ------------------------------------------------------------------ logging ---

variable "log_retention" {
  type        = number
  description = "Retention period (in days) for logs in CloudWatch."
  default     = 90
}

# ------------------------------------------------------------------ network ---

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy example resources into."
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "VPC subnet ID to deploy example resources into."
}

# ================================================================== context ===

variable "aws_region_name" {
  type        = string
  description = "AWS region."
  default     = ""
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID."
  default     = ""
}

variable "aws_kv_namespace" {
  type        = string
  description = "Namespace or prefix for AWS SSM parameters and similar resources."
  default     = ""
}
