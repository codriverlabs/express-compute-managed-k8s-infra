# SSM Document: query installation status without SSH
resource "aws_ssm_document" "status" {
  name            = "eks-dx-status-${var.developer_username}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Query EKS-DX installation status"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "status"
      inputs = {
        runCommand = [
          "MARKER=/opt/eks-d/.installation_complete",
          "if [ -f \"$MARKER\" ]; then",
          "  echo \"STATUS=complete\"",
          "  echo \"COMPLETED_AT=$(cat $MARKER)\"",
          "  kubectl get nodes --no-headers 2>/dev/null | awk '{print \"NODE=\" $1 \" \" $2}' || true",
          "else",
          "  echo \"STATUS=in_progress\"",
          "  STEP=$(grep -o 'Step [0-9]*/[0-9]*' /var/log/cloud-init-output.log 2>/dev/null | tail -1 || echo 'unknown')",
          "  echo \"CURRENT_STEP=$STEP\"",
          "fi"
        ]
      }
    }]
  })

  tags = { Name = "eks-dx-status-${var.developer_username}" }
}

# SSM Document: re-run bootstrap (e.g. after a failed first boot)
resource "aws_ssm_document" "bootstrap" {
  name            = "eks-dx-bootstrap-${var.developer_username}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Re-run EKS-DX workstation bootstrap"
    parameters = {
      DeveloperSignum = {
        type        = "String"
        description = "Developer IAM username / signum"
        default     = var.developer_username
      }
      ClusterName = {
        type        = "String"
        description = "Cluster name"
        default     = local.workstation_name
      }
      Force = {
        type            = "String"
        description     = "Set to 'true' to re-run even if .installation_complete exists"
        default         = "false"
        allowedValues   = ["true", "false"]
      }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "bootstrap"
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "set -e",
          "MARKER=/opt/eks-d/.installation_complete",
          "if [ -f \"$MARKER\" ] && [ \"{{ Force }}\" != \"true\" ]; then",
          "  echo \"Already complete ($(cat $MARKER)). Pass Force=true to re-run.\"",
          "  exit 0",
          "fi",
          "[ \"{{ Force }}\" = \"true\" ] && rm -f \"$MARKER\"",
          "cd /opt/eks-d-setup",
          "bash ./workstation-boot.sh '{{ DeveloperSignum }}' '{{ ClusterName }}'"
        ]
      }
    }]
  })

  tags = { Name = "eks-dx-bootstrap-${var.developer_username}" }
}
