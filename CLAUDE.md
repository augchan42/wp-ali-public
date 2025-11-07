# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a WordPress page publishing system that uses GitHub Actions to automatically convert Markdown files to WordPress pages via SSH and WP-CLI. The workflow bypasses HTTP/API security layers (like SiteGround Anti-Bot AI) by connecting directly via SSH.

## Architecture

### Publishing Pipeline

```
pages/*.md (source files)
    ↓
GitHub Actions (on push to main)
    ↓
Python: Convert Markdown → HTML (out.json)
    ↓
SSH Connection to SiteGround server
    ↓
WP-CLI: Check if page exists by slug
    ↓
WP-CLI: Create new page OR update existing page
    ↓
Published on WordPress
```

### Key Design Decisions

1. **SSH over HTTP/REST API**: Direct WP-CLI access avoids captcha/security plugin issues
2. **Slug-based deduplication**: Uses `wp post list --name='slug'` to check existence before create/update
3. **Markdown-first workflow**: Source of truth is `pages/*.md`, not WordPress database
4. **JSON intermediate format**: Python generates `out.json` with title/slug/content for processing

## Required GitHub Secrets

Configure these in repository Settings → Secrets and variables → Actions:

- `SITEGROUND_SSH_HOST`: SSH hostname (e.g., `ssh.yourdomain.com`)
- `SITEGROUND_SSH_USER`: SSH username (e.g., `u801-xxxxxxxxxx`)
- `SITEGROUND_SSH_KEY`: Full SSH private key (ED25519)
- `SITEGROUND_SSH_PASSPHRASE`: Key passphrase (if applicable)
- `SITEGROUND_WP_PATH`: Absolute path to WordPress installation (e.g., `/home/username/www.domain.com/public_html`)

## Common Development Commands

### Test Markdown Conversion Locally

```bash
python3 -m pip install --upgrade pip markdown jq
python3 - <<'PY'
import glob, json, pathlib, markdown, re
pages = []
for p in glob.glob("pages/**/*.md", recursive=True):
    content = open(p, encoding="utf-8").read()
    heading_match = re.match(r'^#\s+(.+?)$', content, re.MULTILINE)
    if heading_match:
        title = heading_match.group(1).strip()
        content = re.sub(r'^#\s+.+?\n', '', content, count=1)
    else:
        title = pathlib.Path(p).stem.replace('-', ' ').title()
    slug = pathlib.Path(p).stem.lower().replace(' ', '-')
    html_content = markdown.markdown(content)
    pages.append({"title": title, "slug": slug, "content": html_content})
open("out.json", "w", encoding="utf-8").write(json.dumps(pages, ensure_ascii=False, indent=2))
print(f"Prepared {len(pages)} page(s) for publishing")
PY
jq 'length' out.json
```

### Test SSH Connection Locally

```bash
# Replace with actual credentials from secrets/actual-values.md
ssh -p 18765 user@ssh.yourdomain.com "cd /home/username/www.yourdomain.com/public_html && wp post list --post_type=page"
```

### Trigger Workflow Manually

```bash
gh workflow run "Publish WordPress Pages"
```

### Test SSH Workflow (Read-Only)

```bash
gh workflow run "Test SSH Connection"
```

## WP-CLI Commands Reference

See `wp-cli-reference.md` for comprehensive command documentation.

Key commands used in workflow:

- `wp post list --post_type=page --name='slug' --field=ID --format=csv` - Check if page exists
- `wp post create --post_type=page --post_title='...' --post_name='...' --post_content='...' --post_status=publish --porcelain` - Create new page
- `wp post update <ID> --post_title='...' --post_content='...' --post_status=publish` - Update existing page

## File Structure

- `pages/` - Markdown source files (becomes page slugs)
  - Use kebab-case filenames (e.g., `speaker.md`)
  - First `#` heading becomes page title (optional)
  - Filename becomes WordPress slug
- `.github/workflows/` - GitHub Actions workflows
  - `publish-wordpress.yml` - Main publishing pipeline (triggers on push to `pages/**/*.md`)
  - `test-ssh-connection.yml` - Read-only SSH/WP-CLI test (manual trigger)
- `test-ssh-workflow.sh` - Local SSH connection test script
- `out.json` - Generated intermediate file (DO NOT commit)

## Workflow Behavior

### Automatic Triggers

- Pushes to `main` branch that modify `pages/**/*.md` files

### Page Title Extraction

1. If Markdown contains `# Heading` at start, uses that as title and removes from content
2. Otherwise, converts filename to Title Case (e.g., `speaker-bio.md` → "Speaker Bio")

### Create vs Update Logic

```bash
# Workflow checks by slug
page_id=$(wp post list --post_type=page --name='speaker' --field=ID --format=csv)
if [ -n "$page_id" ]; then
  wp post update $page_id ...  # Update existing
else
  wp post create ...           # Create new
fi
```

## Known Issues and Solutions

### SiteGround Anti-Bot AI Blocks GitHub Actions

- **Problem**: SiteGround's Anti-Bot AI (sgcaptcha) blocks REST API requests from GitHub Actions IPs
- **Solution**: This repository bypasses the issue by using SSH + WP-CLI instead of REST API
- **Reference**: See README.md troubleshooting section for details

### Cache Invalidation

- WordPress-level cache is flushed automatically by WP-CLI updates
- SiteGround Dynamic Cache must be manually flushed from Site Tools UI:
  1. Go to https://tools.siteground.com
  2. Speed → Caching → Flush Cache

### Special Characters in Content

- Single quotes are escaped automatically: `sed "s/'/'\\\\''/g"`
- For complex HTML/JavaScript, test locally before pushing

## Site-Specific Configuration

- **WordPress Site**: yourdomain.com (see `secrets/actual-values.md` for actual domain)
- **SSH Port**: 18765 (SiteGround default)
- **WP Path**: `/home/username/www.yourdomain.com/public_html` (see `secrets/actual-values.md` for actual path)
- **Current Pages**: See `wp-cli-reference.md` for page ID reference

## Testing Before Deployment

1. **Preview Markdown**: Use VS Code preview or similar to verify formatting
2. **Validate JSON**: Run `jq empty out.json` after local conversion
3. **Check Unique Slugs**: Ensure filenames don't conflict with existing WordPress pages
4. **Run Test Workflow**: Use "Test SSH Connection" workflow to verify SSH/WP-CLI access

## Git Workflow

- **Branch**: `main` (deployment branch)
- **Commit Style**: Imperative capitalized summaries (see git history)
- **Sensitive Data**: Never commit `out.json`, SSH keys, or credentials
- **Rollback**: Use `git revert` to rollback published changes

## Documentation Files

- `README.md` - Setup instructions and troubleshooting
- `AGENTS.md` - Repository guidelines for AI agents (coding standards, testing, commits)
- `wp-cli-reference.md` - Comprehensive WP-CLI command reference with examples
- `database-vs-static.md` - Technical comparison of database vs static site architectures

## SSH Key Management

- Workflow expects ED25519 or RSA format
- Passphrase-protected keys supported via `expect` script
- Key is added to `ssh-agent` in each workflow step
- Connection uses `StrictHostKeyChecking=no` for CI environment
