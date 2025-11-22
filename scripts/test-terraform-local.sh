#!/bin/bash

# Script to test Terraform locally
# Usage: ./scripts/test-terraform-local.sh [plan|apply]
# 
# You can also set DOCKER_IMAGE environment variable:
#   DOCKER_IMAGE=your-username/devops-strapi:latest ./scripts/test-terraform-local.sh plan

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Terraform Local Testing Script${NC}\n"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Error: Terraform is not installed${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Error: AWS credentials not configured${NC}"
    echo "Please configure AWS credentials:"
    echo "  aws configure"
    echo "  or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}\n"

# Check if terraform.tfvars exists
if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found${NC}"
    echo "Creating terraform.tfvars from example..."
    
    # Generate secrets
    echo -e "\n${GREEN}Generating secrets...${NC}"
    SECRETS=$(node "$SCRIPT_DIR/generate-secrets.js" 2>&1 | grep -E "^(APP_KEYS|ADMIN_JWT_SECRET|JWT_SECRET|API_TOKEN_SALT|TRANSFER_TOKEN_SALT)=")
    
    # Extract values
    APP_KEYS=$(echo "$SECRETS" | grep "APP_KEYS=" | cut -d'=' -f2-)
    ADMIN_JWT_SECRET=$(echo "$SECRETS" | grep "ADMIN_JWT_SECRET=" | cut -d'=' -f2-)
    JWT_SECRET=$(echo "$SECRETS" | grep "JWT_SECRET=" | cut -d'=' -f2-)
    API_TOKEN_SALT=$(echo "$SECRETS" | grep "API_TOKEN_SALT=" | cut -d'=' -f2-)
    TRANSFER_TOKEN_SALT=$(echo "$SECRETS" | grep "TRANSFER_TOKEN_SALT=" | cut -d'=' -f2-)
    
    # Get AWS region
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    
    # Get docker image from environment or use placeholder
    DOCKER_IMAGE="${DOCKER_IMAGE:-your-dockerhub-username/devops-strapi:latest}"
    
    # Create terraform.tfvars
    cat > "$TFVARS_FILE" <<EOF
# Terraform variables for local testing
# Generated automatically - DO NOT commit this file to Git!

# AWS Configuration
aws_region = "$AWS_REGION"

# Application Configuration
app_name     = "devops-strapi"
environment  = "production"

# Docker Image
docker_image = "$DOCKER_IMAGE"

# Strapi Secrets (generated automatically)
app_keys            = "$APP_KEYS"
admin_jwt_secret    = "$ADMIN_JWT_SECRET"
jwt_secret          = "$JWT_SECRET"
api_token_salt      = "$API_TOKEN_SALT"
transfer_token_salt = "$TRANSFER_TOKEN_SALT"

# ECS Task Configuration
task_cpu     = 512
task_memory  = 1024
desired_count = 1
EOF
    
    echo -e "${GREEN}✅ Created terraform.tfvars${NC}"
    if [[ "$DOCKER_IMAGE" == "your-dockerhub-username/devops-strapi:latest" ]]; then
        echo -e "${YELLOW}⚠️  Please update 'docker_image' in terraform.tfvars with your actual Docker image${NC}"
        echo -e "${YELLOW}   Or set DOCKER_IMAGE environment variable:${NC}"
        echo -e "${YELLOW}   DOCKER_IMAGE=your-username/devops-strapi:latest $0${NC}\n"
    fi
else
    echo -e "${GREEN}✅ Found terraform.tfvars${NC}"
    # Update docker_image if DOCKER_IMAGE env var is set
    if [ -n "$DOCKER_IMAGE" ] && grep -q "^docker_image" "$TFVARS_FILE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|^docker_image = .*|docker_image = \"$DOCKER_IMAGE\"|" "$TFVARS_FILE"
        else
            # Linux
            sed -i "s|^docker_image = .*|docker_image = \"$DOCKER_IMAGE\"|" "$TFVARS_FILE"
        fi
        echo -e "${GREEN}✅ Updated docker_image to: $DOCKER_IMAGE${NC}\n"
    else
        echo ""
    fi
fi

# Validate required variables
echo -e "${GREEN}Validating terraform.tfvars...${NC}"
cd "$TERRAFORM_DIR"

# Check if required variables are set
MISSING_VARS=()
WARNINGS=()

# Check docker_image (warning only, Terraform will validate)
if ! grep -q "^docker_image" "$TFVARS_FILE" || grep -q "your-dockerhub-username" "$TFVARS_FILE"; then
    WARNINGS+=("docker_image is not set to a valid Docker image (Terraform will fail if empty)")
fi

# Check secrets (these are required)
if ! grep -q "^app_keys" "$TFVARS_FILE" || [ -z "$(grep "^app_keys" "$TFVARS_FILE" | cut -d'"' -f2)" ]; then
    MISSING_VARS+=("app_keys")
fi

if ! grep -q "^admin_jwt_secret" "$TFVARS_FILE" || [ -z "$(grep "^admin_jwt_secret" "$TFVARS_FILE" | cut -d'"' -f2)" ]; then
    MISSING_VARS+=("admin_jwt_secret")
fi

if ! grep -q "^jwt_secret" "$TFVARS_FILE" || [ -z "$(grep "^jwt_secret" "$TFVARS_FILE" | cut -d'"' -f2)" ]; then
    MISSING_VARS+=("jwt_secret")
fi

if ! grep -q "^api_token_salt" "$TFVARS_FILE" || [ -z "$(grep "^api_token_salt" "$TFVARS_FILE" | cut -d'"' -f2)" ]; then
    MISSING_VARS+=("api_token_salt")
fi

if ! grep -q "^transfer_token_salt" "$TFVARS_FILE" || [ -z "$(grep "^transfer_token_salt" "$TFVARS_FILE" | cut -d'"' -f2)" ]; then
    MISSING_VARS+=("transfer_token_salt")
fi

# Show warnings
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warnings:${NC}"
    printf '  - %s\n' "${WARNINGS[@]}"
    echo ""
fi

# Fail on missing required vars
if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required variables in terraform.tfvars:${NC}"
    printf '  - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

echo -e "${GREEN}✅ All required variables are set${NC}\n"

# Determine action
ACTION="${1:-plan}"

if [ "$ACTION" != "plan" ] && [ "$ACTION" != "apply" ]; then
    echo -e "${RED}❌ Invalid action: $ACTION${NC}"
    echo "Usage: $0 [plan|apply]"
    exit 1
fi

# Initialize Terraform
echo -e "${GREEN}📦 Initializing Terraform...${NC}"
terraform init

# Run terraform plan
echo -e "\n${GREEN}📋 Running Terraform plan...${NC}"
terraform plan

if [ "$ACTION" == "apply" ]; then
    echo -e "\n${YELLOW}⚠️  You requested 'apply' - this will create/modify AWS resources${NC}"
    read -p "Do you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
    
    echo -e "\n${GREEN}🚀 Applying Terraform configuration...${NC}"
    terraform apply
    
    echo -e "\n${GREEN}✅ Terraform apply completed!${NC}"
    echo -e "\n📊 Deployment outputs:"
    terraform output
else
    echo -e "\n${GREEN}✅ Terraform plan completed!${NC}"
    echo -e "\n💡 To apply these changes, run:"
    echo -e "   ${YELLOW}$0 apply${NC}"
fi

echo -e "\n${GREEN}✨ Done!${NC}"

