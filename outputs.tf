output "runners" {
  description = "Information about the runner resources created."
  value = {
    lambda_syncer_name = module.github_runner.binaries_syncer.lambda.function_name
  }
}

output "webhook_endpoint" {
  description = "Endpoint for the webhook resources."
  value       = module.github_runner.webhook.endpoint
}

output "webhook_password" {
  description = "Password for the webhook resources."
  value       = local.webhook_password
}
