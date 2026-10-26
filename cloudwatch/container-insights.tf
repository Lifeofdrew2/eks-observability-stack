# ---------------------------------------------------------------------------
# Amazon CloudWatch Observability EKS add-on
# Installs the CloudWatch agent (Container Insights metrics, enhanced
# observability) and Fluent Bit (container logs to CloudWatch Logs).
# Permissions are granted through EKS Pod Identity to the agent's service
# account only.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${var.cluster_name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = var.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  pod_identity_association {
    role_arn        = aws_iam_role.cloudwatch_agent.arn
    service_account = "cloudwatch-agent"
  }

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_iam_role_policy_attachment.cloudwatch_agent, aws_cloudwatch_log_group.container_insights]
}

# Pre-create the log groups so retention is controlled here rather than
# defaulting to "never expire".
resource "aws_cloudwatch_log_group" "container_insights" {
  for_each = toset(["application", "dataplane", "host", "performance"])

  name              = "/aws/containerinsights/${var.cluster_name}/${each.key}"
  retention_in_days = var.log_retention_days
}
