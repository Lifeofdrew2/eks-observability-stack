locals {
  ci   = "ContainerInsights"
  alb  = "AWS/ApplicationELB"
  cn   = var.cluster_name
  ns   = var.app_namespace
  app  = var.app_name
  lbid = var.alb_arn_suffix

  infra_widgets = [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title  = "Node CPU and memory utilisation (%)"
        region = var.region
        view   = "timeSeries"
        stat   = "Average"
        period = 60
        metrics = [
          [local.ci, "node_cpu_utilization", "ClusterName", local.cn, { label = "CPU" }],
          [local.ci, "node_memory_utilization", "ClusterName", local.cn, { label = "Memory" }],
        ]
        yAxis = { left = { min = 0, max = 100 } }
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title  = "Nodes"
        region = var.region
        view   = "timeSeries"
        stat   = "Maximum"
        period = 60
        metrics = [
          [local.ci, "cluster_node_count", "ClusterName", local.cn, { label = "Total" }],
          [local.ci, "cluster_failed_node_count", "ClusterName", local.cn, { label = "Failed" }],
        ]
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 8, height = 6
      properties = {
        title  = "${local.app}: running pods"
        region = var.region
        view   = "timeSeries"
        stat   = "Minimum"
        period = 60
        metrics = [
          [local.ci, "service_number_of_running_pods", "ClusterName", local.cn, "Namespace", local.ns, "Service", local.app],
        ]
      }
    },
    {
      type = "metric", x = 8, y = 6, width = 8, height = 6
      properties = {
        title  = "${local.app}: pod CPU and memory (% of limit)"
        region = var.region
        view   = "timeSeries"
        stat   = "Average"
        period = 60
        metrics = [
          [local.ci, "pod_cpu_utilization_over_pod_limit", "ClusterName", local.cn, "Namespace", local.ns, "PodName", local.app, { label = "CPU" }],
          [local.ci, "pod_memory_utilization_over_pod_limit", "ClusterName", local.cn, "Namespace", local.ns, "PodName", local.app, { label = "Memory" }],
        ]
      }
    },
    {
      type = "metric", x = 16, y = 6, width = 8, height = 6
      properties = {
        title  = "${local.app}: container restarts"
        region = var.region
        view   = "timeSeries"
        stat   = "Sum"
        period = 300
        metrics = [
          [local.ci, "pod_number_of_container_restarts", "ClusterName", local.cn, "Namespace", local.ns, "PodName", local.app],
        ]
      }
    },
  ]

  alb_widget_list = [
    {
      type = "metric", x = 0, y = 12, width = 12, height = 6
      properties = {
        title  = "ALB requests and 5xx"
        region = var.region
        view   = "timeSeries"
        stat   = "Sum"
        period = 60
        metrics = [
          [local.alb, "RequestCount", "LoadBalancer", local.lbid, { label = "Requests" }],
          [local.alb, "HTTPCode_Target_5XX_Count", "LoadBalancer", local.lbid, { label = "Target 5xx" }],
          [local.alb, "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.lbid, { label = "ALB 5xx" }],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 12, width = 12, height = 6
      properties = {
        title  = "ALB target response time (s)"
        region = var.region
        view   = "timeSeries"
        period = 60
        metrics = [
          [local.alb, "TargetResponseTime", "LoadBalancer", local.lbid, { stat = "p50", label = "p50" }],
          [local.alb, "TargetResponseTime", "LoadBalancer", local.lbid, { stat = "p95", label = "p95" }],
          [local.alb, "TargetResponseTime", "LoadBalancer", local.lbid, { stat = "p99", label = "p99" }],
        ]
      }
    },
  ]
  # ALB metrics only exist once the Ingress has created the load balancer.
  alb_widgets = [for w in local.alb_widget_list : w if local.enable_alb]

  alarm_widget = [{
    type = "alarm", x = 0, y = 18, width = 24, height = 4
    properties = {
      title = "Alarm status"
      alarms = concat(
        [for a in aws_cloudwatch_metric_alarm.cluster : a.arn],
        [
          aws_cloudwatch_metric_alarm.failed_nodes.arn,
          aws_cloudwatch_metric_alarm.app_container_restarts.arn,
          aws_cloudwatch_metric_alarm.app_running_pods.arn,
        ],
        aws_cloudwatch_metric_alarm.alb_5xx_ratio[*].arn,
        aws_cloudwatch_metric_alarm.alb_latency_p95[*].arn,
        aws_cloudwatch_metric_alarm.alb_unhealthy_targets[*].arn,
      )
    }
  }]
}

resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "${var.cluster_name}-overview"
  dashboard_body = jsonencode({ widgets = concat(local.infra_widgets, local.alb_widgets, local.alarm_widget) })
}
