output "sns_topic_arn" {
  description = "Subscribe Slack (via AWS Chatbot), PagerDuty or more emails here."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.platform.dashboard_name}"
}

output "alarm_names" {
  value = concat(
    [for a in aws_cloudwatch_metric_alarm.cluster : a.alarm_name],
    [
      aws_cloudwatch_metric_alarm.failed_nodes.alarm_name,
      aws_cloudwatch_metric_alarm.app_container_restarts.alarm_name,
      aws_cloudwatch_metric_alarm.app_running_pods.alarm_name,
    ],
    aws_cloudwatch_metric_alarm.alb_5xx_ratio[*].alarm_name,
    aws_cloudwatch_metric_alarm.alb_latency_p95[*].alarm_name,
    aws_cloudwatch_metric_alarm.alb_unhealthy_targets[*].alarm_name,
  )
}
