module "github_runner" {
  source = "../../"

  github_app_secrets   = var.github_app_secrets
  github_organization  = var.github_organization
  runner_maximum_count = 10
  runner_labels        = var.runner_labels
  instance_types       = var.instance_types
  log_retention        = 7
  vpc_id               = var.vpc_id
  vpc_subnet_ids       = var.vpc_subnet_ids
}
