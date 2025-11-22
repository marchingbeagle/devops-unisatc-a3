# Setup Guide: Environment Variables and Secrets

This guide will help you obtain all the required environment variables and secrets for your Strapi project with Docker Hub, AWS, and GitHub Actions.

## Table of Contents
1. [Strapi Secrets](#strapi-secrets)
2. [Docker Hub Credentials](#docker-hub-credentials)
3. [AWS Credentials](#aws-credentials)
4. [Setting Up GitHub Secrets](#setting-up-github-secrets)
5. [Local Development (.env file)](#local-development-env-file)

---

## Strapi Secrets

These are cryptographic secrets used by Strapi for security. You need to generate secure random strings for each.

### How to Generate Strapi Secrets

You can generate these secrets using any of the following methods:

#### Option 1: Using Node.js (Recommended)
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

Run this command **4 times** to generate:
- `APP_KEYS` (comma-separated, 4 keys)
- `ADMIN_JWT_SECRET` (1 key)
- `API_TOKEN_SALT` (1 key)
- `TRANSFER_TOKEN_SALT` (1 key)

#### Option 2: Using OpenSSL
```bash
openssl rand -base64 32
```

Run this command **4 times** for the same values as above.

#### Option 3: Using Online Generator
Visit: https://generate-secret.vercel.app/32 (or any secure random string generator)

### Example Values (DO NOT USE THESE - Generate Your Own!)

```
APP_KEYS=abc123xyz,def456uvw,ghi789rst,jkl012mno
ADMIN_JWT_SECRET=your-secret-here-32-chars-min
API_TOKEN_SALT=your-salt-here-32-chars-min
TRANSFER_TOKEN_SALT=your-transfer-salt-32-chars-min
```

**Important:** Each secret should be at least 32 characters long and cryptographically random.

---

## Docker Hub Credentials

Docker Hub is where your Docker images will be stored and published.

### Step 1: Create a Docker Hub Account

1. Go to https://hub.docker.com/
2. Click "Sign Up" in the top right
3. Fill in your details and create an account
4. Verify your email address

### Step 2: Get Your Docker Hub Username

- Your username is the one you chose during signup
- Example: If your Docker Hub URL is `https://hub.docker.com/u/johndoe`, your username is `johndoe`

### Step 3: Create an Access Token (Recommended)

Instead of using your password, create an access token:

1. Log in to Docker Hub
2. Click on your username → **Account Settings**
3. Go to **Security** → **New Access Token**
4. Give it a name (e.g., "GitHub Actions")
5. Set permissions to **Read & Write**
6. Click **Generate**
7. **Copy the token immediately** - you won't be able to see it again!

**Use these values:**
- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: The access token you just created (NOT your password)

---

## AWS Credentials

AWS credentials are needed to deploy your application to AWS ECS using Terraform.

### Step 1: Create an AWS Account

1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. You'll need a credit card, but AWS Free Tier includes:
   - 750 hours/month of t2.micro instances
   - Many other free services for 12 months

### Step 2: Create an IAM User for GitHub Actions

**Important:** Never use your AWS root account credentials. Always create an IAM user.

1. Log in to AWS Console
2. Search for "IAM" in the top search bar
3. Click **Users** → **Create user**
4. Enter a username (e.g., `github-actions-strapi`)
5. Click **Next**

### Step 3: Attach Permissions

1. Select **Attach policies directly**
2. Search for and select these policies:
   - `AmazonECS_FullAccess` (or create a custom policy with minimal permissions)
   - `AmazonEC2ContainerRegistryFullAccess` (if using ECR instead of Docker Hub)
   - `IAMFullAccess` (needed for Terraform to create roles)
   - `AmazonVPCFullAccess` (needed for networking)
   - `ElasticLoadBalancingFullAccess` (needed for ALB)
   - `AmazonRoute53FullAccess` (if using Route53)
   - `SecretsManagerFullAccess` (needed for storing Strapi secrets)
   - `CloudWatchLogsFullAccess` (for logging)

**Note:** For production, create a custom policy with only the permissions you need.

### Step 4: Create Access Keys

1. Click **Next** → **Create user**
2. Click on the newly created user
3. Go to **Security credentials** tab
4. Click **Create access key**
5. Select **Application running outside AWS**
6. Click **Next** → **Create access key**
7. **Download the CSV file** or copy both values:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

**Important:** Save these securely. You won't be able to see the secret key again!

### Step 5: Choose AWS Region

- `AWS_REGION`: Choose a region close to you (e.g., `us-east-1`, `us-west-2`, `eu-west-1`)
- Common regions:
  - `us-east-1` (N. Virginia) - Default, cheapest
  - `us-west-2` (Oregon)
  - `eu-west-1` (Ireland)
  - `sa-east-1` (São Paulo) - If you're in Brazil

---

## Setting Up GitHub Secrets

GitHub Secrets are encrypted environment variables that your GitHub Actions workflows can use.

### Step 1: Navigate to Your Repository

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)

### Step 2: Add Each Secret

Click **New repository secret** for each of the following:

#### Required Secrets:

1. **DOCKER_USERNAME**
   - Name: `DOCKER_USERNAME`
   - Value: Your Docker Hub username

2. **DOCKER_PASSWORD**
   - Name: `DOCKER_PASSWORD`
   - Value: Your Docker Hub access token

3. **AWS_ACCESS_KEY_ID**
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: Your AWS access key ID

4. **AWS_SECRET_ACCESS_KEY**
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: Your AWS secret access key

5. **AWS_REGION**
   - Name: `AWS_REGION`
   - Value: Your chosen AWS region (e.g., `us-east-1`)

6. **APP_KEYS**
   - Name: `APP_KEYS`
   - Value: Your comma-separated Strapi app keys (e.g., `key1,key2,key3,key4`)

7. **ADMIN_JWT_SECRET**
   - Name: `ADMIN_JWT_SECRET`
   - Value: Your Strapi admin JWT secret

8. **API_TOKEN_SALT**
   - Name: `API_TOKEN_SALT`
   - Value: Your Strapi API token salt

9. **TRANSFER_TOKEN_SALT**
   - Name: `TRANSFER_TOKEN_SALT`
   - Value: Your Strapi transfer token salt

### Step 3: Verify Secrets

After adding all secrets, you should see them listed in the Secrets page. They will show as `••••••••` for security.

---

## Local Development (.env file)

For local development, create a `.env` file in the root of your project.

### Step 1: Copy the Example File

```bash
cp env.example .env
```

### Step 2: Edit .env File

Open `.env` and replace the placeholder values:

```bash
# Strapi Configuration
APP_KEYS=your-generated-key1,your-generated-key2,your-generated-key3,your-generated-key4
ADMIN_JWT_SECRET=your-generated-secret
API_TOKEN_SALT=your-generated-salt
TRANSFER_TOKEN_SALT=your-generated-transfer-salt

# Database Configuration
DATABASE_CLIENT=sqlite
DATABASE_FILENAME=.tmp/data.db

# Server Configuration
HOST=0.0.0.0
PORT=1337
NODE_ENV=development
```

**Important:** 
- Use the **same values** you generated for GitHub Secrets (or generate new ones)
- The `.env` file is already in `.gitignore`, so it won't be committed to Git

---

## Quick Checklist

- [ ] Generated 4 Strapi secrets (APP_KEYS, ADMIN_JWT_SECRET, API_TOKEN_SALT, TRANSFER_TOKEN_SALT)
- [ ] Created Docker Hub account
- [ ] Created Docker Hub access token
- [ ] Created AWS account
- [ ] Created AWS IAM user with necessary permissions
- [ ] Created AWS access keys
- [ ] Added all 9 secrets to GitHub repository
- [ ] Created local `.env` file with Strapi secrets

---

## Testing Your Setup

### Test Docker Hub Login Locally

```bash
docker login -u YOUR_DOCKER_USERNAME
# Enter your access token when prompted for password
```

### Test AWS Credentials Locally

```bash
# Install AWS CLI if not already installed
# Then configure:
aws configure
# Enter your AWS_ACCESS_KEY_ID
# Enter your AWS_SECRET_ACCESS_KEY
# Enter your AWS_REGION
# Enter output format (json or text)

# Test connection:
aws sts get-caller-identity
```

### Test GitHub Actions

1. Create a test branch
2. Make a small change
3. Create a Pull Request
4. Check the Actions tab to see if PR checks run successfully

---

## Troubleshooting

### Docker Hub Issues
- **Authentication failed**: Make sure you're using an access token, not your password
- **Permission denied**: Check that your access token has Read & Write permissions

### AWS Issues
- **Access Denied**: Verify your IAM user has the necessary policies attached
- **Region not found**: Make sure your AWS_REGION is correct (e.g., `us-east-1`)

### Strapi Issues
- **Invalid secrets**: Make sure all secrets are at least 32 characters and properly formatted
- **APP_KEYS format**: Must be comma-separated with no spaces (or spaces are fine, Strapi handles it)

---

## Security Best Practices

1. ✅ **Never commit** `.env` file to Git (already in `.gitignore`)
2. ✅ **Use access tokens** instead of passwords for Docker Hub
3. ✅ **Use IAM users** with minimal required permissions, not root account
4. ✅ **Rotate secrets** periodically (every 90 days recommended)
5. ✅ **Use different secrets** for development and production
6. ✅ **Review GitHub Actions logs** regularly for any exposed values

---

## Need Help?

- Docker Hub: https://docs.docker.com/docker-hub/
- AWS IAM: https://docs.aws.amazon.com/IAM/latest/UserGuide/
- GitHub Secrets: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- Strapi Environment Variables: https://docs.strapi.io/dev-docs/configurations/environment

