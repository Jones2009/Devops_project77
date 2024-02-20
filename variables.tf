variable "name" {
  description = "The name of the function"
  type        = string
}

variable "log_groups" {
  description = "CloudWatch Log Group Names"
  default     = {}
  type        = map(any)
}

variable "topic_arns" {
  description = "ARNs for SNS topics."
  default     = {}
  type        = map(any)
}


variable "runtime" {
  description = "The runtime of the Lambda function."
  type        = string
  default     = "java17"
}


variable "deployment_s3_bucket" {
  description = "The name of the S3 Bucket where the Lambda function is stored."
  type        = string
}

variable "function_s3_key" {
  description = "The key of the Lambda function inside of the S3 Bucket."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "region" {
  description = "AWS Region to deploy resources into."
  type        = string
}

variable "deployment_bucket_kms_key_arn" {
  type        = string
  description = "KMS Key ARN to encrypt resources."
}

variable "account_name" {
  type        = string
  description = "The shortname of the AWS accounts, i.e. 'dev', 'stage', etc."
}

variable "security_group_cidr_block_egress" {
  type        = map(any)
  description = "Egress Security Group Rules"
  default     = {}
}

variable "environment_variables" {
  type        = map(any)
  description = "Map of environment variables"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

locals {
  cloudwatch_logs_group_name    = format("/aws/lambda/%s", local.function_name)
  cloudwatch_logs_kms_key_alias = format("alias/slc-%s-%s-cw-%s-kms-%s", var.account_name, var.environment, var.name, local.region[var.region])
  environment_map               = var.environment_variables == null ? [] : [var.environment_variables]
  security_group_name           = format("slc-%s-%s-lambda-%s-sg-%s", var.account_name, var.environment, var.name, local.region[var.region])
  security_group_description    = format("Security Group for %s", local.function_name)
  role_name                     = format("slc-%s-%s-lambda-%s-role-%s", var.account_name, var.environment, var.name, local.region[var.region])
  policy_name                   = format("slc-%s-%s-lambda-%s-policy-%s", var.account_name, var.environment, var.name, local.region[var.region])
  function_name                 = format("slc-%s-%s-lambda-%s-function-%s", var.account_name, var.environment, var.name, local.region[var.region])
  region = {
    eu-west-2 = "euw2"
    eu-west-1 = "euw1"
  }
  tags = {
    environment = var.environment
    region      = local.region[var.region]
    tfmanaged   = "true"
    application = var.name
  }
}


