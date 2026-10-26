variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  description = "Existing EKS cluster (created by the aws-eks-platform repo)."
  type        = string
  default     = "demo-platform-dev"
}

variable "app_namespace" {
  description = "Namespace where demo-api runs."
  type        = string
  default     = "demo"
}

variable "app_name" {
  description = "Deployment / Service name of the application."
  type        = string
  default     = "demo-api"
}

variable "alert_email" {
  description = "Email address subscribed to the alarm SNS topic (you must confirm the subscription email). Leave empty to skip."
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB created by the Ingress (app/k8s-demo-.../abc123). Leave empty to skip ALB alarms until the ALB exists."
  type        = string
  default     = ""
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group (targetgroup/k8s-demo-.../abc123). Needed with alb_arn_suffix for the healthy-hosts alarm."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retention for Container Insights log groups."
  type        = number
  default     = 14
}
