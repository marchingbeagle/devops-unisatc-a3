#!/bin/bash

# Script to destroy all AWS infrastructure managed by Terraform
# Usage: ./scripts/destroy-infrastructure.sh [--auto-approve]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}⚠️  DESTROY AWS INFRASTRUCTURE ⚠️${NC}\n"

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

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ Error: terraform.tfvars not found${NC}"
    echo "Please create terraform.tfvars first or run from terraform directory"
    exit 1
fi

# Get AWS region and name prefix
AWS_REGION=$(grep "^aws_region" terraform.tfvars | cut -d'"' -f2 || echo "us-east-1")
NAME_PREFIX="devops-strapi-production"

echo -e "${YELLOW}This will destroy ALL infrastructure:${NC}"
echo -e "  - ECS Cluster: ${NAME_PREFIX}-cluster"
echo -e "  - ECS Service: ${NAME_PREFIX}-service"
echo -e "  - Task Definitions"
echo -e "  - CloudWatch Log Groups"
echo -e "  - Secrets Manager Secrets"
echo -e "  - Security Groups"
echo -e "  - IAM Roles and Policies"
echo ""
echo -e "${RED}⚠️  WARNING: This action cannot be undone!${NC}\n"

# Check if auto-approve flag is set
if [[ "$1" == "--auto-approve" ]]; then
    AUTO_APPROVE=true
else
    AUTO_APPROVE=false
    read -p "Are you absolutely sure you want to destroy all infrastructure? Type 'yes' to confirm: " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
fi

echo -e "\n${GREEN}Initializing Terraform...${NC}"
terraform init

echo -e "\n${GREEN}Running terraform destroy...${NC}"
if [ "$AUTO_APPROVE" = true ]; then
    terraform destroy -var-file=terraform.tfvars -auto-approve
else
    terraform destroy -var-file=terraform.tfvars
fi

echo -e "\n${GREEN}✅ Infrastructure destruction completed!${NC}"

# Optional: Clean up local Terraform files
echo -e "\n${YELLOW}Clean up local Terraform files?${NC}"
echo "This will remove:"
echo "  - .terraform/ directory"
echo "  - terraform.tfstate* files"
echo "  - .terraform.lock.hcl"

if [ "$AUTO_APPROVE" = true ]; then
    CLEANUP=true
else
    read -p "Clean up local Terraform files? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CLEANUP=true
    else
        CLEANUP=false
    fi
fi

if [ "$CLEANUP" = true ]; then
    echo -e "\n${GREEN}Cleaning up local Terraform files...${NC}"
    rm -rf .terraform/
    rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
    echo -e "${GREEN}✅ Local files cleaned up${NC}"
fi

echo -e "\n${GREEN}✨ Done!${NC}"

