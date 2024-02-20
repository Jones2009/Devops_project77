output "role_arn" {
  value       = aws_iam_role.main.arn
  description = "ARN of the IAM role."
}

output "role_name" {
  value       = aws_iam_role.main.name
  description = "Name of the IAM role."
}

output "function_name" {
  value       = local.function_name
  description = "Name of the Lambda function."
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = local.cloudwatch_logs_group_name
}

output "cloudwatch_log_group_arn" {
      description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.lambda.arn
}


output "security_group_arn" {
  description = "Security Group Name"
  value       = aws_security_group.main.arn
}

output "cloudwatch_logs_kms_key_arn" {
  description = "CloudWatch Log Group KMS Key ARN"
  value       = aws_kms_key.lambda.arn
}