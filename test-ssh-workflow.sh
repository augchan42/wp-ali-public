#!/bin/bash
# Test SSH + WP-CLI workflow locally using GitHub Secrets
# This script is safe and read-only (no destructive operations)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════════"
echo "WordPress SSH + WP-CLI Test Script (Using GitHub Secrets)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if gh CLI is available and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI (gh) is not installed${NC}"
    echo "Install it: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}✗ GitHub CLI is not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${YELLOW}Fetching secrets from GitHub...${NC}"

# Fetch secrets using gh CLI (note: gh CLI cannot read secret values, only list them)
# User must provide credentials via environment variables or prompt
SSH_HOST="${SITEGROUND_SSH_HOST:-}"
SSH_USER="${SITEGROUND_SSH_USER:-}"
SSH_PORT="${SITEGROUND_SSH_PORT:-18765}"

# Note: gh CLI cannot read secret values for security reasons
# We need to show the user what's configured and ask them to verify

echo ""
echo "GitHub Secrets Status:"
gh secret list | grep SITEGROUND || echo "No SITEGROUND secrets found"

echo ""
echo -e "${YELLOW}NOTE: For security, GitHub doesn't allow reading secret values via CLI.${NC}"
echo "You must provide SSH credentials via environment variables or prompts."
echo ""

# Prompt for missing credentials
if [ -z "$SSH_HOST" ]; then
    read -p "SSH Host (or set SITEGROUND_SSH_HOST env var): " SSH_HOST
fi

if [ -z "$SSH_USER" ]; then
    read -p "SSH User (or set SITEGROUND_SSH_USER env var): " SSH_USER
fi

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
    echo -e "${RED}✗ SSH Host and User are required${NC}"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Host: $SSH_HOST"
echo "  User: $SSH_USER"
echo "  Port: $SSH_PORT"
echo ""
read -p "Press Enter to continue with these settings, or Ctrl+C to abort..."

echo ""
echo -e "${YELLOW}Testing SSH Connection...${NC}"
if ssh -p $SSH_PORT -o ConnectTimeout=10 $SSH_USER@$SSH_HOST "echo 'Connection successful'"; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "This could mean:"
    echo "  - Your SSH key is not in ~/.ssh/ or ssh-agent"
    echo "  - The SSH key passphrase is incorrect"
    echo "  - The host/user/port is incorrect"
    exit 1
fi

# Ask for WordPress path since we can't read it from secrets
echo ""
read -p "WordPress Path (check SITEGROUND_WP_PATH secret): " WP_PATH

if [ -z "$WP_PATH" ]; then
    echo -e "${RED}✗ WordPress path is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Testing WP-CLI availability...${NC}"
if ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "cd $WP_PATH && wp --info"; then
    echo -e "${GREEN}✓ WP-CLI is available${NC}"
else
    echo -e "${RED}✗ WP-CLI not found or WordPress path incorrect${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Listing WordPress pages...${NC}"
ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "cd $WP_PATH && wp post list --post_type=page --format=table"

echo ""
echo -e "${YELLOW}Checking if 'speaker-bio' page exists...${NC}"
PAGE_ID=$(ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "cd $WP_PATH && wp post list --post_type=page --name='speaker-bio' --field=ID --format=csv 2>/dev/null | head -n1" || echo "")

if [ -n "$PAGE_ID" ] && [ "$PAGE_ID" != "ID" ]; then
    echo -e "${YELLOW}⚠ Page 'speaker-bio' already exists (ID: $PAGE_ID)${NC}"
    echo "The workflow will UPDATE this page when run."
else
    echo -e "${GREEN}✓ Page 'speaker-bio' does not exist${NC}"
    echo "The workflow will CREATE this page when run."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}All tests passed! Your SSH + WP-CLI setup is working.${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Review the pages listed above"
echo "2. Run the workflow manually from GitHub Actions UI"
echo "3. Monitor the workflow logs for success"
echo ""
