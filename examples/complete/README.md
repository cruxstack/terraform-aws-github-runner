# Example: Complete

This example shows how to use the `cruxstack/github-runner/aws` Terraform module to deploy autoscaling, self-hosted GitHub Action runners on dedicated EC2 instances.

## Usage

To run this example, run as-is or provide your own values for the following
variables in a `.terraform.tfvars` file:

```hcl
github_app_secrets  = { id = "123", key = "NDU2Cg==" } # key is base64 encoded
github_organization = "your-gh-org"
vpc_id              = "vpc-00000000000000"
vpc_subnet_ids      = ["subnet-00000000000000", "subnet-11111111111111111", "subnet-22222222222222222"]
```

## Inputs

| Name                  | Description                                                                         | Type           | Default                       | Required |
|-----------------------|-------------------------------------------------------------------------------------|----------------|-------------------------------|:--------:|
| `github_app_secrets`  | Object containing `id` and `key` for the GitHub app.                                | `object`       | n/a                           |   yes    |
| `github_organization` | Name of the GitHub organization.                                                    | `string`       | n/a                           |   yes    |
| `runner_labels`       | Additional labels for the GitHub Action runners.                                    | `list(string)` | `["tf-example-complete"]`     |    no    |
| `instance_types`      | Set of instance types for the action runner.                                        | `set(string)`  | `["m5ad.large", "m5d.large"]` |    no    |
| `vpc_id`              | ID of the Virtual Private Cloud (VPC) where the example resources will be deployed. | `string`       | n/a                           |   yes    |
| `vpc_subnet_ids`      | List of subnet IDs within the VPC where the example resources will be deployed.     | `list(string)` | n/a                           |   yes    |


## Outputs

| Name      | Description                                      |
|-----------|--------------------------------------------------|
| `runners` | Information about the runner resources created.  |
| `webhook` | Information about the webhook resources created. |
