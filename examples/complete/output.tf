output "runners" {
  description = "Information about the runner resources created."
  value       = module.github_runner.runners
}

output "webhook" {
  description = "Information about the webhook resources created."
  value = {
    secret   = nonsensitive(module.github_runner.webhook_password)
    endpoint = module.github_runner.webhook_endpoint
  }
}
