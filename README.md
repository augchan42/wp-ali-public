# WordPress Pages Publisher

This repository automatically publishes Markdown files from the `pages/` directory to WordPress using GitHub Actions via SSH and WP-CLI.

## Setup

1. **Create GitHub Secrets:**
   - Go to your repository Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `SITEGROUND_SSH_HOST`: Your SSH hostname (e.g., `ssh.yourdomain.com`)
     - `SITEGROUND_SSH_USER`: Your SSH username (e.g., `u801-xxxxxxxxxx`)
     - `SITEGROUND_SSH_KEY`: Your SSH private key (the entire content of your private key file)
     - `SITEGROUND_SSH_PASSPHRASE`: Your SSH key passphrase (if your key has one)
     - `SITEGROUND_WP_PATH`: Absolute path to your WordPress installation (e.g., `/home/username/public_html`)

2. **Generate SSH Key (if you don't have one):**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "github-actions@yourdomain.com"
   ```
   - Save the private key content to `SITEGROUND_SSH_KEY` secret
   - Add the public key to your SiteGround SSH authorized_keys:
     ```bash
     cat ~/.ssh/id_rsa.pub | ssh -p 18765 user@ssh.host.com 'cat >> ~/.ssh/authorized_keys'
     ```

3. **Find Your WordPress Path:**
   - SSH into your server: `ssh -p 18765 user@ssh.host.com`
   - Navigate to your WordPress directory (usually `/home/username/public_html` or similar)
   - Run `pwd` to get the absolute path
   - Add this path to the `SITEGROUND_WP_PATH` secret

## Usage

1. Add Markdown files to the `pages/` directory
2. Commit and push to `main` branch
3. The workflow will automatically convert and publish to WordPress via SSH

## How It Works

- Markdown files in `pages/*.md` are converted to HTML
- GitHub Actions connects to your server via SSH
- Uses WP-CLI to check if a page with the same slug exists
- If exists: updates the existing page using `wp post update`
- If not: creates a new page using `wp post create`
- All pages are published automatically
- Bypasses all HTTP/API security layers (no captcha issues!)

## Troubleshooting

### Issue: SSH Connection Failed

If you see SSH connection errors:

1. **Verify SSH Secrets:**
   - Check that `SITEGROUND_SSH_HOST`, `SITEGROUND_SSH_USER`, `SITEGROUND_SSH_KEY`, and `SITEGROUND_SSH_PASSPHRASE` are set correctly
   - Ensure the SSH key is the complete private key including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`

2. **Test SSH Connection Locally:**
   ```bash
   ssh -p 18765 your_user@your_host.com
   ```
   - If this works, your SSH configuration is correct
   - Copy the same private key to the GitHub secret

3. **Check SSH Key Permissions:**
   - The private key should have restrictive permissions (GitHub Actions handles this automatically)
   - The public key must be in `~/.ssh/authorized_keys` on the server

### Issue: WP-CLI Command Failed

If WP-CLI commands fail:

1. **Verify WordPress Path:**
   - SSH into your server and navigate to your WordPress directory
   - Run `wp --info` to verify WP-CLI is working
   - Update `SITEGROUND_WP_PATH` secret with the correct absolute path

2. **Check WP-CLI Installation:**
   - SiteGround includes WP-CLI by default
   - If missing, install it: https://wp-cli.org/

3. **Verify WordPress Installation:**
   - Ensure `wp-config.php` exists in the WordPress path
   - Test with: `wp post list --post_type=page`

### Issue: Page Content Has Special Characters

If page content with quotes or special characters fails:

- The workflow automatically escapes single quotes
- For complex HTML/JavaScript, consider using WordPress shortcodes instead
- Check the workflow logs for shell escaping errors

