# 🚀 DevOps Unisatc A3 - Strapi CMS

This project implements a complete DevOps pipeline for Strapi CMS with automated testing, Docker containerization, and AWS ECS deployment using Terraform.

## Prerequisites

- Node.js 18+ 
- pnpm (latest-10)
- Docker
- Terraform >= 1.0
- AWS CLI configured with appropriate credentials

## 🔧 Setup Guide

**New to Strapi, AWS, GitHub Actions, or Docker Hub?** 

👉 **See [SETUP_GUIDE.md](./SETUP_GUIDE.md) for a complete step-by-step guide** on how to:
- Generate Strapi secrets
- Create Docker Hub account and access tokens
- Set up AWS credentials
- Configure GitHub Secrets
- Set up local development environment

You can also quickly generate Strapi secrets using:
```bash
node scripts/generate-secrets.js
```

## Getting Started

### Installation

1. Install pnpm globally:
```bash
npm install -g pnpm@latest-10
```

2. Install dependencies:
```bash
pnpm install
```

3. Create a `.env` file with required environment variables:
```bash
APP_KEYS=toBeModified1,toBeModified2,toBeModified3,toBeModified4
ADMIN_JWT_SECRET=toBeModified
API_TOKEN_SALT=toBeModified
TRANSFER_TOKEN_SALT=toBeModified
DATABASE_CLIENT=sqlite
DATABASE_FILENAME=.tmp/data.db
HOST=0.0.0.0
PORT=1337
NODE_ENV=development
```

### Development

Start your Strapi application with autoReload enabled:
```bash
pnpm dev
```

Start your Strapi application with autoReload disabled:
```bash
pnpm start
```

Build your admin panel:
```bash
pnpm build
```

## Testing

### Running E2E Tests Locally

1. Start Strapi server:
```bash
pnpm start
```

2. In another terminal, run Playwright tests:
```bash
pnpm test:e2e
```

3. Run tests in UI mode:
```bash
pnpm test:e2e:ui
```

4. Run tests in headed mode (see browser):
```bash
pnpm test:e2e:headed
```

### Test Collections

The project includes E2E tests for:
- **Article Collection**: Create, Read, Update, Delete operations
- **Author Collection**: Create, Read, Update, Delete operations, and author-article relationships

## Docker

### Build Docker Image

```bash
docker build -t devops-strapi .
```

### Run Docker Container

```bash
docker run -p 1337:1337 \
  -e APP_KEYS="key1,key2,key3,key4" \
  -e ADMIN_JWT_SECRET="secret" \
  -e API_TOKEN_SALT="salt" \
  -e TRANSFER_TOKEN_SALT="transfer-salt" \
  devops-strapi
```

## GitHub Actions

The project includes three GitHub Actions workflows:

### 1. PR Checks (`pr-checks.yml`)
- Runs on pull request creation/updates
- Executes Playwright E2E tests
- Uploads test results as artifacts

### 2. Docker Build (`docker-build.yml`)
- Triggers on push to `main` branch
- Builds Docker image
- Pushes to Docker Hub

### 3. Deploy (`deploy.yml`)
- Triggers on push to `main` branch
- Runs Terraform to deploy infrastructure
- Updates ECS service with new image

### Required GitHub Secrets

Configure the following secrets in your GitHub repository:

- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub password/token
- `AWS_ACCESS_KEY_ID` - AWS access key ID
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key
- `AWS_REGION` - AWS region (default: us-east-1)
- `APP_KEYS` - Comma-separated Strapi app keys
- `ADMIN_JWT_SECRET` - Strapi admin JWT secret
- `API_TOKEN_SALT` - Strapi API token salt
- `TRANSFER_TOKEN_SALT` - Strapi transfer token salt

## Terraform Deployment

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed (>= 1.0)

### Deploy Infrastructure

1. Navigate to terraform directory:
```bash
cd terraform
```

2. Initialize Terraform:
```bash
terraform init
```

3. Review the plan:
```bash
terraform plan \
  -var="docker_image=your-dockerhub-username/devops-strapi:latest" \
  -var="app_keys=key1,key2,key3,key4" \
  -var="admin_jwt_secret=your-secret" \
  -var="api_token_salt=your-salt" \
  -var="transfer_token_salt=your-transfer-salt"
```

4. Apply the configuration:
```bash
terraform apply
```

### Infrastructure Components

The Terraform configuration creates:
- ECS Fargate cluster and service (fixed at 1 task to minimize costs)
- Application Load Balancer
- Security groups for ALB and ECS tasks
- CloudWatch log groups
- AWS Secrets Manager secrets for Strapi configuration
- IAM roles and policies

**Note:** Auto-scaling is disabled to keep costs minimal for this test project.

### Outputs

After deployment, Terraform outputs:
- `cluster_name` - ECS cluster name
- `service_name` - ECS service name
- `load_balancer_url` - Load balancer URL
- `load_balancer_dns` - Load balancer DNS name

## Default Users

The application comes with 3 pre-configured users:

**Super Admin:**
- Email: `admin@satc.edu.br`
- Password: `welcomeToStrapi123`

**Editor:**
- Email: `editor@satc.edu.br`
- Password: `welcomeToStrapi123`

**Author:**
- Email: `author@satc.edu.br`
- Password: `welcomeToStrapi123`

## Collections

The project includes 3 content types:
- **Categoria** (Category)
- **Autor** (Author)
- **Article** (Article)

## Project Structure

```
.
├── .github/workflows/     # GitHub Actions workflows
├── config/                # Strapi configuration
├── src/                   # Strapi source code
├── tests/e2e/            # Playwright E2E tests
├── terraform/            # Terraform infrastructure code
├── Dockerfile            # Docker configuration
└── package.json          # Dependencies and scripts
```

---
<sub>🤫 Psst! [Strapi is hiring](https://strapi.io/careers).</sub>
