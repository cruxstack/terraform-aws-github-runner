locals {
  enabled = coalesce(var.enabled, module.this.enabled, true)
  name    = coalesce(var.name, module.this.name, "github-runner-${random_string.github_runner_random_suffix.result}")

  aws_account_id   = try(coalesce(var.aws_account_id, data.aws_caller_identity.current[0].account_id), "")
  aws_region_name  = try(coalesce(var.aws_region_name, data.aws_region.current[0].name), "")
  aws_kv_namespace = trim(coalesce(var.aws_kv_namespace, "github-runner/${module.github_runner_label.id}"), "/")

  docker_config_sm_secret_name = "${local.aws_kv_namespace}/config/docker"
  webhook_password             = coalesce(var.github_app_webhook_password, random_password.webhook.result)
}

data "aws_caller_identity" "current" {
  count = module.this.enabled && var.aws_account_id == "" ? 1 : 0
}

data "aws_region" "current" {
  count = module.this.enabled && var.aws_region_name == "" ? 1 : 0
}

# ================================================================== runners ===

module "github_runner_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.enabled
  name    = local.name
  context = module.this.context
}

# only appliable if name variable was not set
resource "random_string" "github_runner_random_suffix" {
  length  = 6
  special = false
  upper   = false
}

module "github_runner" {
  source  = "philips-labs/github-runner/aws"
  version = "v4.2.3"

  prefix                                  = module.github_runner_label.id
  enable_ephemeral_runners                = var.runner_ephemeral_mode_enabled
  enable_organization_runners             = var.github_organization_runner_enabled
  minimum_running_time_in_minutes         = var.runner_min_running_time
  runner_extra_labels                     = join(",", var.runner_labels)
  runner_as_root                          = true # required for docker
  runner_iam_role_managed_policy_arns     = [aws_iam_policy.runner.arn]
  runner_binaries_s3_sse_configuration    = { rule = { apply_server_side_encryption_by_default = { sse_algorithm = "AES256" } } }
  runners_maximum_count                   = var.runner_maximum_count
  pool_runner_owner                       = var.github_organization
  scale_up_reserved_concurrent_executions = -1

  aws_region                        = local.aws_region_name
  userdata_template                 = "${path.module}/assets/instance/userdata.sh"
  enable_runner_detailed_monitoring = true
  enable_ssm_on_runners             = true
  ami_filter                        = { name = [var.instance_ami_name], state = ["available"] }
  instance_target_capacity_type     = lower(var.instance_lifecycle_type)
  instance_types                    = var.instance_types
  instance_allocation_strategy      = "capacity-optimized"
  key_name                          = var.key_pair_name
  logging_retention_in_days         = var.log_retention
  subnet_ids                        = var.vpc_subnet_ids
  vpc_id                            = var.vpc_id
  enable_cloudwatch_agent           = false

  idle_config = !var.runner_ephemeral_mode_enabled ? [
    for x in var.runner_pool_config : {
      cron      = x.cron
      timeZone  = x.tz
      idleCount = x.count
    }
  ] : []

  pool_config = var.runner_ephemeral_mode_enabled ? [
    for x in var.runner_pool_config : {
      schedule_expression = "cron(${x.cron})"
      size                = x.count
    }
  ] : []

  block_device_mappings = [{
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = true
    iops                  = 1000
    kms_key_id            = null
    snapshot_id           = null
    throughput            = null
    volume_size           = 100
    volume_type           = "gp3"
  }]

  github_app = {
    key_base64     = var.github_app_secrets.key
    id             = var.github_app_secrets.id
    webhook_secret = local.webhook_password
  }

  runner_metadata_options = {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  ssm_paths = {
    root = "${local.aws_kv_namespace}/config"
  }

  webhook_lambda_zip                = "${module.runner_binaries.artifact_package_path}/webhook.zip"
  runner_binaries_syncer_lambda_zip = "${module.runner_binaries.artifact_package_path}/runner-binaries-syncer.zip"
  runners_lambda_zip                = "${module.runner_binaries.artifact_package_path}/runners.zip"

  tags = merge(
    { for k, v in module.github_runner_label.tags : k => v if lower(k) != "name" },
    { "ghr:docker_config_sm_secret_name" = local.docker_config_sm_secret_name },
  )

  depends_on = [module.runner_binaries]
}

resource "random_password" "webhook" {
  length = 28
}

module "runner_binaries" {
  source  = "cruxstack/artifact-packager/docker"
  version = "1.3.2"

  artifact_src_type      = "directory"
  artifact_dst_directory = "${path.module}/dist"
  artifact_src_path      = "/tmp/runner-binaries"
  docker_build_context   = "${path.module}/assets/runner-binaries"
  docker_build_target    = "package"
  docker_build_args      = { RUNNER_VERSION = trimprefix(var.runner_version, "v") }

  context = module.github_runner_label.context
}

# ---------------------------------------------------------------------- iam ---

data "aws_iam_policy_document" "runner" {
  statement {
    sid    = "AllowSsmParameterAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:us-east-1::parameter/aws/*",
    ]
  }

  statement {
    sid    = "AllowAccessToConfigSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${local.aws_region_name}:${local.aws_account_id}:secret:${local.docker_config_sm_secret_name}-*",
    ]
  }
}

resource "aws_iam_policy" "runner" {
  name   = "${module.github_runner_label.id}-action-runner-custom"
  policy = data.aws_iam_policy_document.runner.json
}

# ============================================================== docker-auth ===

resource "aws_secretsmanager_secret" "docker_config" {
  name = local.docker_config_sm_secret_name
}

resource "aws_secretsmanager_secret_version" "docker_login" {
  secret_id = aws_secretsmanager_secret.docker_config.id
  secret_string = jsonencode({
    logins = var.docker_logins
  })
}
