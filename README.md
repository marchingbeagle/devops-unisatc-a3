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

## GitHub Actions CI/CD Pipeline

The project includes a complete CI/CD pipeline with three GitHub Actions workflows:

### 1. PR Checks Workflow (`.github/workflows/pr-checks.yml`)

**Triggers:** Pull request events (opened, synchronize, reopened)

**What it does:**

- Checks out the code
- Sets up Node.js 18 environment
- Installs dependencies using pnpm
- Installs Playwright browsers
- Builds the Strapi application
- Starts Strapi server in production mode
- Waits for server to be ready
- Runs Playwright E2E tests
- Uploads test results and screenshots as artifacts

**Artifacts:**

- Test reports (HTML format)
- Screenshots (on test failures)

### 2. Docker Build Workflow (`.github/workflows/docker-build.yml`)

**Triggers:** Push to `main` branch

**What it does:**

- Checks out the code
- Sets up Docker Buildx
- Logs in to Docker Hub
- Builds Docker image with multiple tags:
  - `{branch}-{sha}` (e.g., `main-abc123`)
  - `latest`
  - `{date}-{sha}` (e.g., `20240101-abc123`)
- Pushes images to Docker Hub
- Uses Docker layer caching for faster builds

**Image Tags:**

- Images are tagged with commit SHA for traceability
- `latest` tag always points to the most recent build

### 3. Deploy Workflow (`.github/workflows/deploy.yml`)

**Triggers:** Push to `main` branch or manual workflow dispatch

**What it does:**

- Checks out the code
- Configures AWS credentials
- Sets up Terraform
- Determines Docker image tag (uses commit SHA or latest)
- Initializes Terraform
- Runs Terraform plan
- Applies Terraform configuration to deploy:
  - ECS Fargate cluster and service
  - Security groups
  - CloudWatch log groups
  - AWS Secrets Manager secrets
  - IAM roles and policies
- Waits for ECS service to be healthy
- Outputs deployment information (cluster name, service name, URL, public IP)

**Deployment Process:**

1. Terraform creates/updates AWS infrastructure
2. ECS service pulls the Docker image from Docker Hub
3. New task starts with the updated image
4. Health checks ensure service is running
5. Old task is stopped after new one is healthy.

**Workflow Execution:**

- PR Checks workflow runs automatically on every PR
- Docker Build and Deploy workflows run in parallel on push to `main`
- Deploy workflow uses the `latest` Docker image tag (updated by Docker Build workflow)
- If Deploy runs before Docker Build completes, it will use the previous `latest` image

### Setting Up GitHub Secrets

**📖 See [.github/SECRETS.md](.github/SECRETS.md) for detailed setup instructions.**

Quick summary of required secrets:

**Docker Hub:**

- `DOCKER_USERNAME` - Your Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub password or access token

**AWS:**

- `AWS_ACCESS_KEY_ID` - AWS access key ID
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key
- `AWS_REGION` - AWS region (optional, defaults to `us-east-1`)

**Strapi Configuration:**

- `STRAPI_APP_KEYS` - Comma-separated list of 4 app keys
- `STRAPI_ADMIN_JWT_SECRET` - Admin JWT secret
- `STRAPI_API_TOKEN_SALT` - API token salt
- `STRAPI_TRANSFER_TOKEN_SALT` - Transfer token salt

Generate Strapi secrets using:

```bash
node scripts/generate-secrets.js
```

### Creating Test Pull Requests

To demonstrate the CI/CD pipeline, create two pull requests:

#### 1. Passing PR

1. Create a new branch:

   ```bash
   git checkout -b feature/test-passing-pr
   ```

2. Make a small change (e.g., update README or add a comment)

3. Commit and push:

   ```bash
   git add .
   git commit -m "Test: Passing PR"
   git push origin feature/test-passing-pr
   ```

4. Create a pull request on GitHub
5. The PR Checks workflow will run automatically
6. All tests should pass ✅

#### 2. Failing PR

1. Create a new branch:

   ```bash
   git checkout -b feature/test-failing-pr
   ```

2. Modify a test to intentionally fail. For example, edit `tests/e2e/article.spec.ts`:

   ```typescript
   // Change this line:
   expect(data.data.title).toBe("Test Article");

   // To this (wrong expected value):
   expect(data.data.title).toBe("Wrong Title");
   ```

3. Commit and push:

   ```bash
   git add tests/e2e/article.spec.ts
   git commit -m "Test: Intentionally failing test"
   git push origin feature/test-failing-pr
   ```

4. Create a pull request on GitHub
5. The PR Checks workflow will run automatically
6. Tests will fail ❌, demonstrating the CI pipeline catching errors

### Verifying Deployments

After a successful deployment:

1. **Check GitHub Actions output:**

   - Go to Actions tab in your repository
   - Click on the latest Deploy workflow run
   - Check the "Get deployment outputs" step for service URL and IP

2. **Get deployment info via Terraform:**

   ```bash
   cd terraform
   terraform output service_url
   terraform output task_public_ip
   ```

3. **Access the deployed application:**

   - Use the public IP from Terraform outputs
   - Access Strapi admin at: `http://{public-ip}:1337/admin`
   - Login with: `admin@satc.edu.br` / `welcomeToStrapi123`

4. **Check ECS service status:**

   ```bash
   aws ecs describe-services \
     --cluster devops-strapi-production-cluster \
     --services devops-strapi-production-service \
     --region us-east-1
   ```

5. **View logs:**
   ```bash
   aws logs tail /ecs/devops-strapi-production --follow --region us-east-1
   ```

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
