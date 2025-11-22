#!/bin/bash

# Script to import existing AWS resources into Terraform state
# Usage: ./scripts/import-existing-resources.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}📥 Terraform Resource Import Script${NC}\n"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Error: Terraform is not installed${NC}"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Error: AWS credentials not configured${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Get AWS region from terraform.tfvars or default
AWS_REGION=$(grep "^aws_region" terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "us-east-1")
export AWS_DEFAULT_REGION="$AWS_REGION"

# Get name prefix
NAME_PREFIX="devops-strapi-production"

echo -e "${GREEN}Using region: $AWS_REGION${NC}"
echo -e "${GREEN}Resource prefix: $NAME_PREFIX${NC}\n"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo -e "${GREEN}Initializing Terraform...${NC}"
    terraform init
fi

# Load variables from terraform.tfvars if it exists
if [ -f "terraform.tfvars" ]; then
    echo -e "${GREEN}Loading variables from terraform.tfvars...${NC}"
    # Extract variables for terraform import
    DOCKER_IMAGE=$(grep "^docker_image" terraform.tfvars | cut -d'"' -f2 || echo "")
    APP_KEYS=$(grep "^app_keys" terraform.tfvars | cut -d'"' -f2 || echo "")
    ADMIN_JWT_SECRET=$(grep "^admin_jwt_secret" terraform.tfvars | cut -d'"' -f2 || echo "")
    API_TOKEN_SALT=$(grep "^api_token_salt" terraform.tfvars | cut -d'"' -f2 || echo "")
    TRANSFER_TOKEN_SALT=$(grep "^transfer_token_salt" terraform.tfvars | cut -d'"' -f2 || echo "")
    
    # Build terraform import command with variables
    TF_VARS="-var=\"docker_image=$DOCKER_IMAGE\""
    TF_VARS="$TF_VARS -var=\"app_keys=$APP_KEYS\""
    TF_VARS="$TF_VARS -var=\"admin_jwt_secret=$ADMIN_JWT_SECRET\""
    TF_VARS="$TF_VARS -var=\"api_token_salt=$API_TOKEN_SALT\""
    TF_VARS="$TF_VARS -var=\"transfer_token_salt=$TRANSFER_TOKEN_SALT\""
    TF_VARS="$TF_VARS -var=\"aws_region=$AWS_REGION\""
    TF_VARS="$TF_VARS -input=false"
else
    echo -e "${YELLOW}⚠️  terraform.tfvars not found, imports may fail if variables are required${NC}"
    TF_VARS="-input=false"
fi

# Function to safely import a resource
safe_import() {
    local resource=$1
    local identifier=$2
    local description=${3:-$resource}
    
    echo -e "${YELLOW}Importing $description...${NC}"
    
    # Check if resource already exists in state
    if terraform state show "$resource" &> /dev/null; then
        echo -e "${GREEN}  ✓ Already in state, skipping${NC}"
        return 0
    fi
    
    # Try to import with variables
    if eval "terraform import $TF_VARS \"$resource\" \"$identifier\"" 2>&1; then
        echo -e "${GREEN}  ✓ Successfully imported${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to import (resource may not exist or already imported)${NC}"
        return 1
    fi
}

echo -e "${GREEN}Starting import process...${NC}\n"

# Import CloudWatch Log Group
safe_import \
    "aws_cloudwatch_log_group.strapi" \
    "/ecs/${NAME_PREFIX}" \
    "CloudWatch Log Group"

# Import Secrets Manager secrets
safe_import \
    "aws_secretsmanager_secret.app_keys" \
    "${NAME_PREFIX}-app-keys" \
    "Secrets Manager Secret (app_keys)"

safe_import \
    "aws_secretsmanager_secret.admin_jwt_secret" \
    "${NAME_PREFIX}-admin-jwt-secret" \
    "Secrets Manager Secret (admin_jwt_secret)"

safe_import \
    "aws_secretsmanager_secret.api_token_salt" \
    "${NAME_PREFIX}-api-token-salt" \
    "Secrets Manager Secret (api_token_salt)"

safe_import \
    "aws_secretsmanager_secret.transfer_token_salt" \
    "${NAME_PREFIX}-transfer-token-salt" \
    "Secrets Manager Secret (transfer_token_salt)"

# Get VPC ID for security group import
echo -e "\n${YELLOW}Finding VPC and Security Group...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region "${AWS_REGION}" 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo -e "${GREEN}  Found VPC: $VPC_ID${NC}"
    
    # Get security group ID by name
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${NAME_PREFIX}-ecs-tasks-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --query "SecurityGroups[0].GroupId" \
        --output text \
        --region "${AWS_REGION}" 2>/dev/null || echo "")
    
    if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
        safe_import \
            "aws_security_group.ecs_tasks" \
            "$SG_ID" \
            "Security Group"
    else
        echo -e "${YELLOW}  ⚠ Security group not found${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Default VPC not found${NC}"
fi

# Import IAM Roles
safe_import \
    "aws_iam_role.ecs_task_execution" \
    "${NAME_PREFIX}-ecs-task-execution-role" \
    "IAM Role (ecs_task_execution)"

safe_import \
    "aws_iam_role.ecs_task" \
    "${NAME_PREFIX}-ecs-task-role" \
    "IAM Role (ecs_task)"

# Import ECS Service if it exists
echo -e "\n${YELLOW}Checking for ECS Service...${NC}"
SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster "${NAME_PREFIX}-cluster" \
    --services "${NAME_PREFIX}-service" \
    --query 'services[0].status' \
    --output text \
    --region "${AWS_REGION}" 2>/dev/null || echo "None")

if [ "$SERVICE_EXISTS" = "ACTIVE" ] || [ "$SERVICE_EXISTS" = "DRAINING" ]; then
    safe_import \
        "aws_ecs_service.strapi" \
        "${NAME_PREFIX}-cluster/${NAME_PREFIX}-service" \
        "ECS Service"
else
    echo -e "${GREEN}  ✓ ECS Service doesn't exist yet (will be created)${NC}"
fi

echo -e "\n${GREEN}✅ Import process completed!${NC}\n"

echo -e "${GREEN}Verifying state...${NC}"
terraform state list

echo -e "\n${GREEN}✨ Next steps:${NC}"
echo -e "  1. Run ${YELLOW}terraform plan${NC} to see what Terraform wants to change"
echo -e "  2. If everything looks good, run ${YELLOW}terraform apply${NC}"

