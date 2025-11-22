output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.strapi.name
}

# Data source to get the running ECS task's public IP
data "external" "ecs_task_ip" {
  program = ["bash", "-c", <<-EOT
    CLUSTER_NAME="${aws_ecs_cluster.main.name}"
    SERVICE_NAME="${aws_ecs_service.strapi.name}"
    
    # Get the task ARN
    TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --query 'taskArns[0]' --output text 2>/dev/null)
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
      echo '{"public_ip":"","status":"no_task_running"}'
      exit 0
    fi
    
    # Get the task details including network configuration
    TASK_DETAILS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].attachments[0].details' --output json 2>/dev/null)
    
    # Extract the ENI ID
    ENI_ID=$(echo "$TASK_DETAILS" | grep -o '"value": "[^"]*eni-[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$ENI_ID" ]; then
      echo '{"public_ip":"","status":"eni_not_found"}'
      exit 0
    fi
    
    # Get the public IP from the ENI
    PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null)
    
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
      echo '{"public_ip":"","status":"no_public_ip"}'
      exit 0
    fi
    
    echo "{\"public_ip\":\"$PUBLIC_IP\",\"status\":\"success\"}"
  EOT
  ]
  
  depends_on = [aws_ecs_service.strapi]
}

output "task_public_ip" {
  description = "Public IP address of the running ECS task"
  value       = data.external.ecs_task_ip.result.public_ip != "" ? data.external.ecs_task_ip.result.public_ip : "Task not running or IP not available yet. Run 'terraform refresh' to update."
}

output "service_url" {
  description = "Full URL to access the Strapi service"
  value       = data.external.ecs_task_ip.result.public_ip != "" ? "http://${data.external.ecs_task_ip.result.public_ip}:1337" : "Service not available yet. Run 'terraform refresh' to update."
}

