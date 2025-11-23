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

# Function to always return to original branch
cleanup_and_return() {
    local exit_code=$?
    # Temporarily disable set -e to ensure cleanup runs
    set +e
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$CURRENT_BRANCH" ] && [ "$current_branch" != "$CURRENT_BRANCH" ]; then
        echo -e "\n${YELLOW}Cleaning up: Returning to ${CURRENT_BRANCH}...${NC}" >&2
        git checkout "$CURRENT_BRANCH" 2>&1 >/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Returned to ${CURRENT_BRANCH}${NC}" >&2
        else
            echo -e "${RED}❌ Failed to return to ${CURRENT_BRANCH}${NC}" >&2
            echo -e "${YELLOW}⚠️  Please manually run: git checkout ${CURRENT_BRANCH}${NC}" >&2
        fi
    fi
    exit $exit_code
}

# Set up trap to always return to original branch on exit/error
# This ensures we always return to master even if script fails
trap cleanup_and_return EXIT INT TERM

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
echo -e "${BLUE}📤 Pushing branches to GitHub...${NC}\n"

# Temporarily disable exit on error for push operations
# We want to continue even if pushes fail
set +e

# Track push success
FAILING_PUSHED=0
PASSING_PUSHED=0

# Function to push a branch and verify it was pushed
push_branch() {
    local branch=$1
    local branch_display=$2
    
    echo -e "${GREEN}Pushing ${branch_display}...${NC}"
    
    # Checkout the branch
    if ! git checkout "$branch" 2>&1; then
        echo -e "${RED}  ❌ Failed to checkout ${branch_display}${NC}\n"
        return 1
    fi
    
    # Show what we're about to push
    local commit_count=$(git rev-list --count HEAD ^"$CURRENT_BRANCH" 2>/dev/null || echo "?")
    echo -e "${BLUE}  📝 Branch has ${commit_count} commit(s) to push${NC}"
    
    # Check if branch exists on remote (informational only)
    if git show-ref --verify --quiet refs/remotes/origin/"$branch" 2>/dev/null; then
        echo -e "${BLUE}  ℹ️  Updating existing branch on GitHub${NC}"
    else
        echo -e "${BLUE}  ℹ️  Creating new branch on GitHub${NC}"
    fi
    
    # Try force-with-lease first (works for both new and existing branches)
    local push_output
    push_output=$(git push -u origin "$branch" --force-with-lease 2>&1)
    local push_status=$?
    
    if [ $push_status -eq 0 ]; then
        echo -e "${GREEN}  ✅ Successfully pushed ${branch_display} to GitHub${NC}"
        echo -e "${GREEN}  ✅ Branch is now available on GitHub${NC}\n"
        return 0
    else
        # Show the error for debugging
        echo -e "${YELLOW}  ⚠️  Force-with-lease failed: ${push_output}${NC}"
        echo -e "${YELLOW}  ⚠️  Trying regular force push...${NC}"
        
        # Fallback to regular force push
        push_output=$(git push -u origin "$branch" --force 2>&1)
        push_status=$?
        
        if [ $push_status -eq 0 ]; then
            echo -e "${GREEN}  ✅ Successfully pushed ${branch_display} to GitHub (force)${NC}"
            echo -e "${GREEN}  ✅ Branch is now available on GitHub${NC}\n"
            return 0
        else
            echo -e "${RED}  ❌ Failed to push ${branch_display}${NC}"
            echo -e "${RED}  Error: ${push_output}${NC}"
            echo -e "${YELLOW}  ⚠️  Check your git credentials and network connection${NC}\n"
            return 1
        fi
    fi
}

# Push failing branch
if push_branch "$FAILING_BRANCH" "${FAILING_BRANCH}"; then
    FAILING_PUSHED=1
fi

# Push passing branch
if push_branch "$PASSING_BRANCH" "${PASSING_BRANCH}"; then
    PASSING_PUSHED=1
fi

# Verify branches are on remote
echo -e "${BLUE}Verifying branches on GitHub...${NC}"
git fetch origin 2>&1 >/dev/null

if git show-ref --verify --quiet refs/remotes/origin/"$FAILING_BRANCH"; then
    echo -e "${GREEN}  ✅ Verified: ${FAILING_BRANCH} exists on GitHub${NC}"
else
    echo -e "${RED}  ❌ Warning: ${FAILING_BRANCH} not found on GitHub${NC}"
fi

if git show-ref --verify --quiet refs/remotes/origin/"$PASSING_BRANCH"; then
    echo -e "${GREEN}  ✅ Verified: ${PASSING_BRANCH} exists on GitHub${NC}"
else
    echo -e "${RED}  ❌ Warning: ${PASSING_BRANCH} not found on GitHub${NC}"
fi
echo ""

# Re-enable exit on error
set -e

# Return to original branch (trap will handle this if script exits early)
echo -e "${BLUE}Returning to original branch: ${CURRENT_BRANCH}${NC}"
set +e  # Temporarily disable exit on error for checkout
git checkout "$CURRENT_BRANCH" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✅ Returned to ${CURRENT_BRANCH}${NC}\n"
    # Disable trap since we're already on the correct branch
    trap - EXIT INT TERM
else
    echo -e "${RED}  ❌ Failed to return to ${CURRENT_BRANCH}${NC}"
    echo -e "${YELLOW}  ⚠️  You are currently on: $(git branch --show-current 2>/dev/null || echo 'unknown')${NC}"
    echo -e "${YELLOW}  ⚠️  The cleanup trap will attempt to return you to ${CURRENT_BRANCH}${NC}\n"
fi
set -e  # Re-enable exit on error

# ============================================
# Display instructions
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $FAILING_PUSHED -eq 1 ] && [ $PASSING_PUSHED -eq 1 ]; then
    echo -e "${GREEN}✅ SUCCESS: Both demo branches created and pushed to GitHub!${NC}\n"
    echo -e "${GREEN}You now have 2 new branches on GitHub:${NC}"
    echo -e "  • ${FAILING_BRANCH}"
    echo -e "  • ${PASSING_BRANCH}\n"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📋 Next Steps: Create Pull Requests on GitHub${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Both branches are available on GitHub. You can now create PRs:${NC}\n"
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

# Get repository info for URLs
REPO_URL=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")

if [ $FAILING_PUSHED -eq 1 ] && [ $PASSING_PUSHED -eq 1 ]; then
    echo -e "${YELLOW}📝 Create Pull Requests:${NC}\n"
    echo -e "${YELLOW}1. FAILING PR (tests will fail):${NC}"
    echo -e "   ${GREEN}Branch:${NC} ${FAILING_BRANCH}"
    if [ -n "$REPO_URL" ]; then
        echo -e "   ${GREEN}URL:${NC} https://github.com/${REPO_URL}/compare/master...${FAILING_BRANCH}?expand=1"
    fi
    echo -e "   ${GREEN}Expected:${NC} ❌ Tests will fail (E2E test expects wrong value)"
    echo ""
    
    echo -e "${YELLOW}2. PASSING PR (tests will pass):${NC}"
    echo -e "   ${GREEN}Branch:${NC} ${PASSING_BRANCH}"
    if [ -n "$REPO_URL" ]; then
        echo -e "   ${GREEN}URL:${NC} https://github.com/${REPO_URL}/compare/master...${PASSING_BRANCH}?expand=1"
    fi
    echo -e "   ${GREEN}Expected:${NC} ✅ All tests will pass"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ Script completed successfully!${NC}"
    echo -e "${GREEN}✨ Both branches are now on GitHub and ready for PR creation.${NC}\n"
elif [ $FAILING_PUSHED -eq 1 ] || [ $PASSING_PUSHED -eq 1 ]; then
    echo -e "${YELLOW}📝 Create Pull Requests (for successfully pushed branches):${NC}\n"
    if [ $FAILING_PUSHED -eq 1 ]; then
        echo -e "${YELLOW}1. FAILING PR:${NC}"
        echo -e "   ${GREEN}Branch:${NC} ${FAILING_BRANCH}"
        if [ -n "$REPO_URL" ]; then
            echo -e "   ${GREEN}URL:${NC} https://github.com/${REPO_URL}/compare/master...${FAILING_BRANCH}?expand=1"
        fi
        echo ""
    fi
    if [ $PASSING_PUSHED -eq 1 ]; then
        echo -e "${YELLOW}2. PASSING PR:${NC}"
        echo -e "   ${GREEN}Branch:${NC} ${PASSING_BRANCH}"
        if [ -n "$REPO_URL" ]; then
            echo -e "   ${GREEN}URL:${NC} https://github.com/${REPO_URL}/compare/master...${PASSING_BRANCH}?expand=1"
        fi
        echo ""
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  Script completed with warnings. Some branches may need manual push.${NC}\n"
else
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ Script completed but branches were not pushed to GitHub.${NC}"
    echo -e "${YELLOW}Please check your git credentials and try pushing manually.${NC}\n"
fi

