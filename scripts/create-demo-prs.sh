#!/bin/bash

# Script to create demo PR branches (one failing, one passing) for presentation
# Usage: ./scripts/create-demo-prs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Creating Demo PR Branches${NC}\n"

# Check if git is available
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Error: Git is not installed${NC}"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${YELLOW}Current branch: ${CURRENT_BRANCH}${NC}"

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}❌ Error: You have uncommitted changes${NC}"
    echo "Please commit or stash your changes before running this script"
    exit 1
fi

# Check if we're on master (recommended but not required)
if [ "$CURRENT_BRANCH" != "master" ] && [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Warning: You're not on master/main branch${NC}"
    echo -e "${YELLOW}   It's recommended to run this from master/main${NC}"
    read -p "Continue anyway? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
fi

# Fetch latest changes
echo -e "\n${GREEN}Fetching latest changes from remote...${NC}"
git fetch origin

# Branch names
FAILING_BRANCH="demo/pr-failing"
PASSING_BRANCH="demo/pr-passing"

# Function to check if branch exists locally or remotely
branch_exists() {
    local branch=$1
    git show-ref --verify --quiet refs/heads/"$branch" || \
    git show-ref --verify --quiet refs/remotes/origin/"$branch"
}

# Function to delete branch if it exists
delete_branch_if_exists() {
    local branch=$1
    if git show-ref --verify --quiet refs/heads/"$branch"; then
        echo -e "${YELLOW}  ⚠️  Branch '$branch' exists locally, deleting...${NC}"
        git branch -D "$branch" 2>/dev/null || true
    fi
    if git show-ref --verify --quiet refs/remotes/origin/"$branch"; then
        echo -e "${YELLOW}  ⚠️  Branch '$branch' exists on remote, will be overwritten on push${NC}"
    fi
}

# Check if branches already exist and delete them if needed
if branch_exists "$FAILING_BRANCH"; then
    echo -e "${YELLOW}⚠️  Branch '$FAILING_BRANCH' already exists${NC}"
    delete_branch_if_exists "$FAILING_BRANCH"
fi

if branch_exists "$PASSING_BRANCH"; then
    echo -e "${YELLOW}⚠️  Branch '$PASSING_BRANCH' already exists${NC}"
    delete_branch_if_exists "$PASSING_BRANCH"
fi

echo -e "\n${GREEN}Creating branches for demo PRs...${NC}\n"

# ============================================
# Create FAILING PR branch
# ============================================
echo -e "${BLUE}📝 Creating branch: ${FAILING_BRANCH}${NC}"

# Create and checkout branch
git checkout -b "$FAILING_BRANCH"

# Modify the test to intentionally fail
TEST_FILE="tests/e2e/article.spec.ts"
if [ ! -f "$TEST_FILE" ]; then
    echo -e "${RED}❌ Error: Test file not found: $TEST_FILE${NC}"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$FAILING_BRANCH" 2>/dev/null || true
    exit 1
fi

# Create a backup
cp "$TEST_FILE" "$TEST_FILE.bak"

# Modify line 93 to have wrong expectation
sed -i "s/expect(data.data.title).toBe('Test Article');/expect(data.data.title).toBe('Wrong Title');/" "$TEST_FILE"

# Verify the change was made
if grep -q "Wrong Title" "$TEST_FILE"; then
    echo -e "${GREEN}  ✅ Modified test to intentionally fail${NC}"
else
    echo -e "${RED}  ❌ Failed to modify test file${NC}"
    mv "$TEST_FILE.bak" "$TEST_FILE"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$FAILING_BRANCH" 2>/dev/null || true
    exit 1
fi

# Remove backup
rm "$TEST_FILE.bak"

# Stage and commit the change
echo -e "${GREEN}  Staging changes...${NC}"
git add "$TEST_FILE"
echo -e "${GREEN}  Committing changes...${NC}"
git commit -m "Test: Intentionally failing E2E test for demo

This PR demonstrates a failing CI check. The test expects 'Wrong Title' 
instead of 'Test Article', causing the E2E tests to fail."

# Verify commit was created
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Committed failing test (commit: $(git rev-parse --short HEAD))${NC}\n"
else
    echo -e "${RED}  ❌ Failed to create commit${NC}"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$FAILING_BRANCH" 2>/dev/null || true
    exit 1
fi

# ============================================
# Create PASSING PR branch
# ============================================
echo -e "${BLUE}📝 Creating branch: ${PASSING_BRANCH}${NC}"

# Go back to base branch and create new branch
git checkout "$CURRENT_BRANCH"
git checkout -b "$PASSING_BRANCH"

# Add a helpful comment to the test file
COMMENT_LINE="  // This test verifies that articles can be created and retrieved correctly"
if ! grep -q "This test verifies that articles can be created" "$TEST_FILE"; then
    # Find the line with the test description and add comment before it
    sed -i "/test('should create a new article')/i\\
$COMMENT_LINE" "$TEST_FILE"
    echo -e "${GREEN}  ✅ Added helpful comment to test file${NC}"
else
    echo -e "${YELLOW}  ⚠️  Comment already exists, skipping${NC}"
fi

# Stage and commit the change
echo -e "${GREEN}  Staging changes...${NC}"
git add "$TEST_FILE"
echo -e "${GREEN}  Committing changes...${NC}"
git commit -m "Test: Passing PR for demo

This PR demonstrates a passing CI check. Added a helpful comment 
to improve test documentation."

# Verify commit was created
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Committed passing change (commit: $(git rev-parse --short HEAD))${NC}\n"
else
    echo -e "${RED}  ❌ Failed to create commit${NC}"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$PASSING_BRANCH" 2>/dev/null || true
    exit 1
fi

# ============================================
# Push branches to remote
# ============================================
echo -e "${BLUE}📤 Pushing branches to remote...${NC}\n"

# Track push success
FAILING_PUSHED=0
PASSING_PUSHED=0

# Push failing branch (with commits)
echo -e "${GREEN}Pushing ${FAILING_BRANCH} with commits...${NC}"
if git checkout "$FAILING_BRANCH" 2>&1; then
    # Try force-with-lease first (safer)
    if git push -u origin "$FAILING_BRANCH" --force-with-lease 2>&1; then
        echo -e "${GREEN}  ✅ Pushed ${FAILING_BRANCH} to remote${NC}"
        echo -e "${GREEN}  ✅ Commits are now available on GitHub${NC}\n"
        FAILING_PUSHED=1
    else
        echo -e "${YELLOW}  ⚠️  Force-with-lease failed, trying regular force push...${NC}"
        # Fallback to regular force push
        if git push -u origin "$FAILING_BRANCH" --force 2>&1; then
            echo -e "${GREEN}  ✅ Pushed ${FAILING_BRANCH} to remote (force)${NC}"
            echo -e "${GREEN}  ✅ Commits are now available on GitHub${NC}\n"
            FAILING_PUSHED=1
        else
            echo -e "${RED}  ❌ Failed to push ${FAILING_BRANCH}${NC}"
            echo -e "${YELLOW}  ⚠️  Check your git credentials and network connection${NC}\n"
        fi
    fi
else
    echo -e "${RED}  ❌ Failed to checkout ${FAILING_BRANCH}${NC}\n"
fi

# Push passing branch (with commits)
echo -e "${GREEN}Pushing ${PASSING_BRANCH} with commits...${NC}"
if git checkout "$PASSING_BRANCH" 2>&1; then
    # Try force-with-lease first (safer)
    if git push -u origin "$PASSING_BRANCH" --force-with-lease 2>&1; then
        echo -e "${GREEN}  ✅ Pushed ${PASSING_BRANCH} to remote${NC}"
        echo -e "${GREEN}  ✅ Commits are now available on GitHub${NC}\n"
        PASSING_PUSHED=1
    else
        echo -e "${YELLOW}  ⚠️  Force-with-lease failed, trying regular force push...${NC}"
        # Fallback to regular force push
        if git push -u origin "$PASSING_BRANCH" --force 2>&1; then
            echo -e "${GREEN}  ✅ Pushed ${PASSING_BRANCH} to remote (force)${NC}"
            echo -e "${GREEN}  ✅ Commits are now available on GitHub${NC}\n"
            PASSING_PUSHED=1
        else
            echo -e "${RED}  ❌ Failed to push ${PASSING_BRANCH}${NC}"
            echo -e "${YELLOW}  ⚠️  Check your git credentials and network connection${NC}\n"
        fi
    fi
else
    echo -e "${RED}  ❌ Failed to checkout ${PASSING_BRANCH}${NC}\n"
fi

# Always return to original branch
echo -e "${BLUE}Returning to original branch: ${CURRENT_BRANCH}${NC}"
if git checkout "$CURRENT_BRANCH" 2>&1; then
    echo -e "${GREEN}  ✅ Returned to ${CURRENT_BRANCH}${NC}\n"
else
    echo -e "${RED}  ❌ Failed to return to ${CURRENT_BRANCH}${NC}"
    echo -e "${YELLOW}  ⚠️  You are currently on: $(git branch --show-current 2>/dev/null || echo 'unknown')${NC}"
    echo -e "${YELLOW}  ⚠️  Please manually checkout ${CURRENT_BRANCH}${NC}\n"
    exit 1
fi

# ============================================
# Display instructions
# ============================================
if [ $FAILING_PUSHED -eq 1 ] && [ $PASSING_PUSHED -eq 1 ]; then
    echo -e "${GREEN}✅ Demo branches created and pushed successfully!${NC}\n"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📋 Next Steps: Create Pull Requests Manually on GitHub${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Both branches have been pushed to GitHub with their commits.${NC}"
    echo -e "${GREEN}You can now create the PRs manually using the links below:${NC}\n"
elif [ $FAILING_PUSHED -eq 1 ] || [ $PASSING_PUSHED -eq 1 ]; then
    echo -e "${YELLOW}⚠️  Demo branches created, but some pushes failed${NC}\n"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📋 Status Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ $FAILING_PUSHED -eq 1 ]; then
        echo -e "${GREEN}✅ ${FAILING_BRANCH} pushed successfully${NC}"
    else
        echo -e "${RED}❌ ${FAILING_BRANCH} push failed${NC}"
    fi
    if [ $PASSING_PUSHED -eq 1 ]; then
        echo -e "${GREEN}✅ ${PASSING_BRANCH} pushed successfully${NC}"
    else
        echo -e "${RED}❌ ${PASSING_BRANCH} push failed${NC}"
    fi
    echo -e "\n${YELLOW}You can manually push the branches using:${NC}"
    echo -e "  git push -u origin ${FAILING_BRANCH} --force"
    echo -e "  git push -u origin ${PASSING_BRANCH} --force\n"
else
    echo -e "${RED}❌ Demo branches created locally, but pushes failed${NC}\n"
    echo -e "${YELLOW}You can manually push the branches using:${NC}"
    echo -e "  git push -u origin ${FAILING_BRANCH} --force"
    echo -e "  git push -u origin ${PASSING_BRANCH} --force\n"
fi

echo -e "${YELLOW}1. Create FAILING PR:${NC}"
echo -e "   ${GREEN}Branch:${NC} ${FAILING_BRANCH}"
echo -e "   ${GREEN}URL:${NC} https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/master...${FAILING_BRANCH}?expand=1"
echo -e "   ${GREEN}Expected:${NC} ❌ Tests will fail (E2E test expects wrong value)"
echo ""

echo -e "${YELLOW}2. Create PASSING PR:${NC}"
echo -e "   ${GREEN}Branch:${NC} ${PASSING_BRANCH}"
echo -e "   ${GREEN}URL:${NC} https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/master...${PASSING_BRANCH}?expand=1"
echo -e "   ${GREEN}Expected:${NC} ✅ All tests will pass"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Done!${NC}\n"

