# Terraform Module: AWS GitHub Action Runner

This Terraform module deploys autoscaling, self-hosted GitHub Action runners on
dedicated EC2 instances. It is an extension of the popular [`philips-labs/github-runner/aws` module](https://github.com/philips-labs/terraform-aws-github-runner),
 with additional features to add value to your GitHub Action runners.

## Features

- **Auto-Scaling Runners**: Automatically scales the number of runners based on
  demand.
- **Ephemeral Runners**: Provides an option to use ephemeral runners that are
  destroyed after use.
- **Tag-Based Runner Assignment**: Uses tags to assign runners to specific
  tasks.
- **Custom Runner Configuration**: Allows custom configuration of runners,
  including instance types, AMIs, and more.
- **Instance Store RAID**: If more than 2 instance stores are detected, they are
  combined into a `RAID0` configuration for improved performance.
- **Automated Docker Login**: If custom Docker authentication is configured, the
  runners will automatically perform a `docker login`.

## Usage

```hcl
module "github_runner" {
  source  = "cruxstack/github-runner/aws"
  version = "x.x.x"

  github_app_secrets = {
    id  = "your_github_app_id"
    key = "your_github_app_key"
  }

  github_organization = "your_github_organization_name"
}
```

## Inputs

In addition to the variables documented below, this module includes several
other optional variables (e.g., `name`, `tags`, etc.) provided by the
`cloudposse/label/null` module. Please refer to the [`cloudposse/label` documentation](https://registry.terraform.io/modules/cloudposse/label/null/latest) for more details on these variables.

| Name                                 | Description                                                                                 | Type           | Default                               | Required |
|--------------------------------------|---------------------------------------------------------------------------------------------|----------------|---------------------------------------|:--------:|
| `github_app_secrets`                 | Object containing `id` and `key` for the GitHub app.                                        | `object`       | n/a                                   |   yes    |
| `github_organization`                | Name of the GitHub organization.                                                            | `string`       | n/a                                   |   yes    |
| `github_app_webhook_password`        | Password for the GitHub app webhook. An empty string implies a randomly generated password. | `string`       | `""`                                  |    no    |
| `github_organization_runner_enabled` | Toggle to activate runners for all projects in the organization.                            | `bool`         | `true`                                |    no    |
| `runner_binaries_path`               | Path to the GitHub Action runner binaries saved locally before pushed to S3.                | `string`       | `""`                                  |    no    |
| `runner_ephemeral_mode_enabled`      | Toggle to activate ephemeral runners.                                                       | `bool`         | `false`                               |    no    |
| `runner_os`                          | Operating system for the GitHub Action runner.                                              | `string`       | `"linux"`                             |    no    |
| `instance_ami_name`                  | Name of the Amazon Machine Image (AMI) for the GitHub Action runner.                        | `string`       | `"al2023-ami-2023.*-kernel-*-x86_64"` |    no    |
| `instance_types`                     | Set of instance types for the action runner.                                                | `set(string)`  | `["m5ad.large", "m5d.large"]`         |    no    |
| `instance_lifecycle_type`            | Lifecycle type for action runner instances. Options: `spot` or `on-demand`.                 | `string`       | `"spot"`                              |    no    |
| `log_retention`                      | Retention period (in days) for logs in CloudWatch.                                          | `number`       | `90`                                  |    no    |
| `vpc_id`                             | ID of the Virtual Private Cloud (VPC).                                                      | `string`       | n/a                                   |   yes    |
| `vpc_subnet_ids`                     | List of subnet IDs within the VPC.                                                          | `list(string)` | n/a                                   |   yes    |
| `aws_region_name`                    | AWS region.                                                                                 | `string`       | `""`                                  |    no    |
| `aws_account_id`                     | AWS account ID.                                                                             | `string`       | `""`                                  |    no    |
| `aws_kv_namespace`                   | Namespace or prefix for AWS SSM parameters and similar resources.                           | `string`       | `""`                                  |    no    |

## Outputs

| Name               | Description                                     |
|--------------------|-------------------------------------------------|
| `runners`          | Information about the runner resources created. |
| `webhook_endpoint` | Endpoint for the webhook resources.             |
| `webhook_password` | Password for the webhook resources.             |


## Contributing

We welcome contributions to this project. For information on setting up a
development environment and how to make a contribution, see [CONTRIBUTING](./CONTRIBUTING.md)
documentation.
