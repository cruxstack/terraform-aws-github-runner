variable "github_app_secrets" {
  type = object({
    id  = string
    key = string
  })
  description = "Object containing `id` and `key` for the GitHub app."
}

variable "github_organization" {
  type        = string
  description = "Name of the GitHub organization."
}

variable "runner_labels" {
  type        = list(string)
  description = "Additional labels for the GitHub Action runners."
  default     = ["tf-example-complete"]
}

variable "instance_types" {
  type        = set(string)
  description = "Set of instance types for the action runner."
  default     = ["m5ad.large", "m5d.large"]
}

variable "vpc_id" {
  type        = string
  description = "ID of the Virtual Private Cloud (VPC) where the example resources will be deployed."
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs within the VPC where the example resources will be deployed."
}
