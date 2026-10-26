resource "aws_sns_topic" "alerts" {
  name              = "${var.cluster_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  cluster_dims  = { ClusterName = var.cluster_name }
  enable_alb    = var.alb_arn_suffix != ""

  # Container Insights node / cluster alarms.
  cluster_alarms = {
    node-cpu-high = {
      metric      = "node_cpu_utilization"
      threshold   = 80
      description = "Average node CPU above 80% for 15 minutes - the node group may need to scale out."
    }
    node-memory-high = {
      metric      = "node_memory_utilization"
      threshold   = 85
      description = "Average node memory above 85% for 15 minutes - risk of pod eviction."
    }
    node-filesystem-high = {
      metric      = "node_filesystem_utilization"
      threshold   = 85
      description = "Node root filesystem above 85% - image garbage collection or eviction may start."
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "cluster" {
  for_each = local.cluster_alarms

  alarm_name          = "${var.cluster_name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "ContainerInsights"
  metric_name         = each.value.metric
  dimensions          = local.cluster_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.threshold
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "failed_nodes" {
  alarm_name          = "${var.cluster_name}-failed-nodes"
  alarm_description   = "One or more worker nodes are failing health checks."
  namespace           = "ContainerInsights"
  metric_name         = "cluster_failed_node_count"
  dimensions          = local.cluster_dims
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "app_container_restarts" {
  alarm_name          = "${var.cluster_name}-${var.app_name}-restarts"
  alarm_description   = "${var.app_name} containers restarted more than 3 times in 15 minutes (crash loop or failing liveness probe)."
  namespace           = "ContainerInsights"
  metric_name         = "pod_number_of_container_restarts"
  dimensions          = merge(local.cluster_dims, { Namespace = var.app_namespace, PodName = var.app_name })
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "app_running_pods" {
  alarm_name          = "${var.cluster_name}-${var.app_name}-running-pods-low"
  alarm_description   = "Fewer than 2 ${var.app_name} pods running - availability across AZs is reduced."
  namespace           = "ContainerInsights"
  metric_name         = "service_number_of_running_pods"
  dimensions          = merge(local.cluster_dims, { Namespace = var.app_namespace, Service = var.app_name })
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 5
  comparison_operator = "LessThanThreshold"
  threshold           = 2
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------------------------------------------------------------------------
# Load balancer alarms (enabled once the Ingress has created the ALB)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx_ratio" {
  count = local.enable_alb ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.app_name}-alb-5xx-ratio"
  alarm_description   = "More than 1% of requests through the ALB returned 5xx for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 1
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "ratio"
    expression  = "100 * (errors_target + errors_elb) / MAX([requests, 1])"
    label       = "5xx percentage"
    return_data = true
  }
  metric_query {
    id = "errors_target"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      stat        = "Sum"
      period      = 300
    }
  }
  metric_query {
    id = "errors_elb"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      stat        = "Sum"
      period      = 300
    }
  }
  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      stat        = "Sum"
      period      = 300
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  count = local.enable_alb ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.app_name}-alb-p95-latency"
  alarm_description   = "p95 target response time above 500ms for 15 minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0.5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = local.enable_alb && var.target_group_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.app_name}-alb-healthy-hosts-low"
  alarm_description   = "Fewer than 2 healthy targets behind the ALB."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 2
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}
