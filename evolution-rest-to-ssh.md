# Evolution: From WordPress REST API to SSH + WP-CLI

A detailed timeline of how this project evolved from using WordPress REST API to SSH + WP-CLI, documenting the problems encountered and solutions implemented.

## Timeline

### Phase 1: Initial REST API Implementation (Nov 5, 2025 - 3:38 PM)

**Commit:** `97e7399` - "Add GitHub Actions workflow for publishing WordPress pages"

**Approach:**
- Used WordPress REST API with Application Passwords for authentication
- Markdown → HTML conversion in GitHub Actions
- Created/updated pages via HTTP POST requests to `/wp-json/wp/v2/pages`
- Checked for existing pages by slug, then either update or create

**Configuration Required:**
```yaml
Secrets:
  - WP_BASE_URL: https://yourdomain.com/wp-json/wp/v2
  - WP_APP_AUTH: username:application_password
```

**Code Pattern:**
```bash
# Get page ID by slug
page_id=$(curl -s -u "$WP_AUTH" "$WP_BASE/pages?slug=$slug" | jq '.[0].id')

# Update or create
if [ -n "$page_id" ]; then
  curl -u "$WP_AUTH" -X POST "$WP_BASE/pages/$page_id" -d '...'
else
  curl -u "$WP_AUTH" -X POST "$WP_BASE/pages" -d '...'
fi
```

**Why This Seemed Good:**
- WordPress REST API is the "official" way to interact with WordPress programmatically
- Application Passwords are secure and designed for this use case
- No SSH access required
- Clean HTTP-based integration

---

### Phase 2: First Contact with SiteGround Security (Nov 5 - 5:36 PM)

**Commits:** `fa1166a`, `9e4b031` - Adding error handling and authentication checks

**Problem Discovered:**
- API requests returning HTTP 202 instead of 200
- Response bodies contained `sgcaptcha` or captcha-related HTML
- SiteGround Anti-Bot AI was challenging/blocking automated requests

**Response HTML Example:**
```html
<html>
  <head>...sgcaptcha...</head>
  <body><!-- Bot detection challenge --></body>
</html>
```

**Initial Attempts:**
1. **Better Error Detection**
   - Added authentication testing before operations
   - Checked for HTTP 202 (captcha redirect)
   - Grepped response for "sgcaptcha", "captcha", "security"

2. **Batch API Implementation**
   - Thought: "Maybe making fewer requests will help avoid rate limiting"
   - Implemented WordPress Batch API (5.6+) support
   - Could publish multiple pages in one request instead of N requests
   - Fallback to individual requests if batch unavailable

3. **Better Logging**
   - Added HTTP status codes to all responses
   - Logged full response bodies for debugging
   - Showed current GitHub Actions IP address

**Code Added:**
```bash
# Test authentication first
auth_test=$(curl -s -w "\n%{http_code}" -u "$WP_AUTH" "$WP_BASE/pages?per_page=1")
auth_code=$(echo "$auth_test" | tail -n1)
auth_body=$(echo "$auth_test" | sed '$d')

if [ "$auth_code" -eq 202 ] || echo "$auth_body" | grep -q "sgcaptcha"; then
  echo "✗ BLOCKED: SiteGround Anti-Bot AI"
  # ... error message ...
fi
```

**Why This Didn't Work:**
- SiteGround Anti-Bot AI operates at a layer **below** WordPress
- It intercepts requests before they even reach WordPress PHP
- No amount of WordPress-level configuration could fix it
- The protection was specifically designed to block automated/bot-like traffic
- GitHub Actions IPs were automatically flagged as suspicious

---

### Phase 3: Comprehensive Documentation of the Problem (Nov 5 - 7:14 PM)

**Commit:** `d2e0e0c` - "Enhance WordPress publishing workflow with improved error handling"

**The Realization:**
SiteGround Anti-Bot AI **cannot be disabled from Site Tools**. It requires contacting support.

**Documentation Added:**
The workflow now included a detailed error message when captcha was detected:

```
════════════════════════════════════════════════════════════════
ISSUE: SiteGround's Anti-Bot Protection
════════════════════════════════════════════════════════════════

Your site is protected by SiteGround's Anti-Bot AI system which
automatically challenges requests that appear to be from bots.
GitHub Actions triggers this protection.

This CANNOT be disabled from Site Tools.

════════════════════════════════════════════════════════════════
SOLUTION: Contact SiteGround Support (Recommended)
════════════════════════════════════════════════════════════════

1. Open a support ticket: https://my.siteground.com/support/tickets

2. Copy and paste this message:

   Subject: Disable Anti-Bot AI for WordPress REST API

   Message:
   My site's Anti-Bot AI (sgcaptcha) is blocking WordPress REST API
   requests from GitHub Actions CI/CD. I need this disabled for
   /wp-json/* endpoints or the following IPs whitelisted:

   Current GitHub Actions IP: [automatically detected]

   Please whitelist GitHub Actions IPs or disable Anti-Bot AI for
   authenticated REST API requests.
```

**Alternative Workarounds Documented:**

1. **SiteGround Security Plugin:**
   - Add GitHub Actions IPs to whitelist
   - May not work for all challenges

2. **functions.php Hack:**
```php
add_filter('sg_security_skip_antibot', function($skip) {
    if (isset($_SERVER['HTTP_USER_AGENT']) &&
        strpos($_SERVER['HTTP_USER_AGENT'], 'curl') !== false) {
        return true;
    }
    return $skip;
});
```
   - Reduces security
   - May not work at infrastructure level

**The Problem:**
- Waiting for SiteGround support could take days
- The workarounds were unreliable or reduced security
- The REST API approach was fundamentally blocked

---

### Phase 4: The Pivot to SSH + WP-CLI (Nov 5 - 8:39 PM)

**Commit:** `97719ac` - "Add SSH connection test workflow"

**The Insight:**
> "What if we bypass HTTP entirely and use SSH + WP-CLI?"

**Why SSH + WP-CLI Solves Everything:**

1. **Bypasses All HTTP Security Layers**
   - Anti-Bot AI only protects HTTP/HTTPS traffic
   - SSH is a completely different protocol
   - Direct server access, no web server involved

2. **WP-CLI is Already Installed**
   - SiteGround includes WP-CLI by default
   - It's the command-line interface to WordPress
   - Same power as REST API, but from inside the server

3. **More Reliable**
   - No HTTP timeouts or rate limits
   - No captcha challenges
   - No cookie/session management needed

4. **Better for Automation**
   - SSH keys are standard CI/CD practice
   - Deterministic results
   - Better error messages

**New Configuration Required:**
```yaml
Secrets:
  - SITEGROUND_SSH_HOST: ssh.yourdomain.com
  - SITEGROUND_SSH_USER: u801-xxxxxxxxxx
  - SITEGROUND_SSH_KEY: [Full ED25519 private key]
  - SITEGROUND_SSH_PASSPHRASE: [Key passphrase if applicable]
  - SITEGROUND_WP_PATH: /home/username/www.yourdomain.com/public_html
```

**Initial Test Workflow:**
Created a safe, read-only test workflow to verify SSH setup:
- Test SSH connection
- Run `wp --info` to verify WP-CLI
- List pages with `wp post list --post_type=page`
- Check if speaker-bio exists
- **NO modifications**, pure read-only testing

---

### Phase 5: SSH Implementation Challenges (Nov 5 - 8:42 PM to 8:57 PM)

**Commits:** `73af0ce` through `9c9efd9` - Various SSH fixes

The SSH approach worked, but required several iterations:

#### Challenge 1: SSH Key Format
**Problem:** Initial workflow expected RSA keys, but modern keys use ED25519
**Solution:** Changed `id_rsa` to `id_ed25519` throughout

```bash
# Before
echo "$SSH_KEY" > ~/.ssh/id_rsa

# After
printf '%s\n' "$SSH_KEY" > ~/.ssh/id_ed25519  # Preserves newlines
```

#### Challenge 2: Preserving Newlines
**Problem:** SSH keys have strict formatting with newlines
**Solution:** Use `printf '%s\n'` instead of `echo`

#### Challenge 3: Passphrase Handling
**Problem:** `ssh-add` prompts for passphrase interactively (doesn't work in CI)
**Solution:** Use `expect` to automate passphrase entry

```bash
sudo apt-get install -y expect

expect -c "
  set timeout 10
  spawn ssh-add $::env(HOME)/.ssh/id_ed25519
  expect \"Enter passphrase for\"
  send \"$::env(SSH_PASSPHRASE)\r\"
  expect eof
"
```

#### Challenge 4: SSH Agent Persistence
**Problem:** SSH agent doesn't persist between GitHub Actions steps

This revealed a fundamental aspect of GitHub Actions: **runners are ephemeral**. Each step runs in a new shell session, so the ssh-agent process from "Step 1: Setup SSH" is no longer available in "Step 2: Publish pages". The runner is also completely destroyed after the workflow completes.

**Solution:** Restart agent and re-add key in each step that needs SSH

```bash
# In each step that needs SSH
eval "$(ssh-agent -s)"
# ... add key with expect ...
```

This pattern of "setup from scratch in every step" became a key design principle (see Key Learning #5 below).

#### Challenge 5: Expect Script Debugging
**Problem:** Getting the expect script to work correctly took multiple iterations:
- Initially tried using a heredoc to create an expect script file
- YAML heredoc syntax conflicted with expect syntax (quotes, escaping)
- File path issues (`~/.ssh/id_ed25519` vs `$HOME/.ssh/id_ed25519`)
- Need to use `$::env(HOME)` in expect to access environment variables

**Evolution:**
```bash
# Attempt 1: Heredoc to file (failed - YAML syntax issues)
cat > /tmp/ssh-add.exp <<'EOF'
...
EOF

# Attempt 2: Fixed file path (failed - variable expansion)
expect /tmp/ssh-add.exp

# Final: Inline expect command (works!)
expect -c "
  set timeout 10
  spawn ssh-add $::env(HOME)/.ssh/id_ed25519
  expect \"Enter passphrase for\"
  send \"$::env(SSH_PASSPHRASE)\r\"
  expect eof
"
```

**Lesson:** When embedding one scripting language (expect) in another (bash) in YAML, inline commands are more maintainable than heredocs.

#### Challenge 6: Environment Variables Must Be Repeated
**Problem:** Each workflow step is isolated - environment variables don't persist

This meant we had to define the same ENV vars multiple times:

```yaml
- name: Setup SSH
  env:
    SSH_HOST: ${{ secrets.SITEGROUND_SSH_HOST }}
    SSH_USER: ${{ secrets.SITEGROUND_SSH_USER }}
    SSH_KEY: ${{ secrets.SITEGROUND_SSH_KEY }}
    SSH_PASSPHRASE: ${{ secrets.SITEGROUND_SSH_PASSPHRASE }}
    SSH_PORT: 18765
  run: ...

- name: Publish via SSH + WP-CLI
  env:
    # Must redefine ALL the same vars again!
    SSH_HOST: ${{ secrets.SITEGROUND_SSH_HOST }}
    SSH_USER: ${{ secrets.SITEGROUND_SSH_USER }}
    SSH_PASSPHRASE: ${{ secrets.SITEGROUND_SSH_PASSPHRASE }}
    SSH_PORT: 18765
    WP_PATH: ${{ secrets.SITEGROUND_WP_PATH }}
  run: ...
```

**Why this happens:** GitHub Actions steps run in fresh shell sessions. Environment variables defined at the job level would help, but we needed step-specific scoping for clarity.

**Trade-off accepted:** Repetition (verbose but explicit) over magic (DRY but harder to debug).

---

### Phase 6: Final SSH + WP-CLI Implementation (Nov 5 - 8:57 PM)

**Commit:** `9c9efd9` - "Apply SSH agent fix to main workflow and finalize documentation"

**Final Architecture:**

```
Markdown Files (pages/*.md)
    ↓
GitHub Actions (on push to main)
    ↓
Python: Convert MD → HTML → out.json
    ↓
Setup SSH (keys, agent, known_hosts)
    ↓
SSH into SiteGround server
    ↓
WP-CLI: wp post list --name='slug' --field=ID
    ↓
WP-CLI: wp post create OR wp post update
    ↓
Published on WordPress (cache auto-cleared)
```

**Key Commands:**
```bash
# Check if page exists
page_id=$(ssh -p 18765 $SSH_USER@$SSH_HOST \
  "cd $WP_PATH && wp post list --post_type=page --name='$slug' --field=ID --format=csv")

# Create new page
ssh -p 18765 $SSH_USER@$SSH_HOST \
  "cd $WP_PATH && wp post create \
    --post_type=page \
    --post_title='$title' \
    --post_name='$slug' \
    --post_content='$content' \
    --post_status=publish \
    --porcelain"

# Update existing page
ssh -p 18765 $SSH_USER@$SSH_HOST \
  "cd $WP_PATH && wp post update $page_id \
    --post_title='$title' \
    --post_content='$content' \
    --post_status=publish"
```

**Benefits Achieved:**
- ✅ No SiteGround Anti-Bot AI issues
- ✅ No HTTP timeouts or rate limits
- ✅ Faster execution (direct server access)
- ✅ Better error messages from WP-CLI
- ✅ Can do more complex operations (menus, plugins, cache)
- ✅ WordPress cache auto-cleared by WP-CLI updates

---

## Key Learnings

### 1. **HTTP Security Can Be Too Good**
Modern hosting providers like SiteGround have aggressive bot protection that's **impossible to disable** from the control panel. Even legitimate API requests with proper authentication get blocked because the traffic pattern looks automated.

### 2. **The "Official" Way Isn't Always the Best Way**
WordPress REST API is the official, recommended approach. But when hosting infrastructure blocks it, you need alternatives. WP-CLI via SSH is actually **more robust** for automation.

### 3. **Layer Understanding Matters**
The key insight was understanding where the blockage occurred:
- ❌ WordPress-level (we had auth working)
- ❌ Web server level (PHP was never reached)
- ✅ **Infrastructure level** (before traffic hits web server)

Once we understood it was infrastructure-level blocking, SSH became the obvious solution.

### 4. **Test Workflows Are Valuable**
Creating a separate read-only test workflow (`test-ssh-connection.yml`) allowed safe experimentation without risking the production site. This pattern is valuable for any CI/CD setup.

### 5. **GitHub Actions Runners Are Ephemeral**
This was a critical realization that shaped the entire SSH implementation:

**What "ephemeral" means:**
- Each workflow run starts with a **completely fresh Ubuntu VM**
- No files, keys, or configuration persist between runs
- The runner is **destroyed immediately** after the workflow completes
- Even between **steps in the same workflow**, state doesn't automatically persist

**Why this matters for SSH:**
```yaml
Step 1: Setup SSH
  - Create ~/.ssh/id_ed25519
  - Start ssh-agent
  - Add key to agent
  ✓ SSH works here

Step 2: Publish pages
  - ssh-agent is GONE (new shell session)
  - Need to restart ssh-agent
  - Need to re-add key
  ✓ Now SSH works again
```

**The solution:**
Every step that needs SSH must:
1. Restart the SSH agent: `eval "$(ssh-agent -s)"`
2. Re-add the key with `expect` script for passphrase
3. Treat it as a fresh environment

**Why this is different from persistent CI:**
- Jenkins/TeamCity on dedicated servers: SSH keys can persist, agent runs continuously
- GitHub Actions: **No persistence whatsoever**, setup from scratch every time
- Can't cache SSH connections, can't reuse agents, can't store state

**The benefit:**
- Clean slate every run (no "works on my machine" issues)
- No leaked secrets or state between runs
- Reproducible builds (what works once, works always)

This is why we needed `expect` scripts in **multiple steps** rather than just once at the start.

### 6. **CI/CD SSH is Well-Solved**
While SSH setup seemed complex initially (passphrases, agents, key formats), these are actually well-understood problems with standard solutions. The `expect` tool and SSH agent patterns work reliably.

### 7. **YAML + Bash + Expect = Three-Layer Debugging**
Working with GitHub Actions means debugging across three scripting languages simultaneously:

**The layers:**
1. **YAML** (workflow syntax, secret interpolation, step definitions)
2. **Bash** (the `run:` commands)
3. **Expect** (automating interactive prompts)

**Common gotchas:**
- YAML heredoc syntax conflicts with bash heredoc syntax
- Bash variable expansion (`$HOME`) vs expect variable syntax (`$::env(HOME)`)
- Quoting nightmares: YAML quotes → bash quotes → expect quotes
- Environment variable scoping (job level vs step level)

**The solution that worked:**
- Use inline expect commands instead of heredoc script files
- Repeat environment variable definitions in each step (verbose but clear)
- Test each layer independently before combining

**Pro tip:** If a multi-line script isn't working, try the inline approach first. Simplicity beats elegance when debugging.

### 8. **WP-CLI is Powerful**
WP-CLI can do everything the REST API can do, plus:
- Clear cache: `wp cache flush`
- Manage menus: `wp menu item add-post`
- Check WordPress health: `wp --info`
- Database operations: `wp db export`
- Plugin management: `wp plugin list`

### 9. **Direct Server Access Wins for Automation**
For programmatic/AI agent access to WordPress:
- REST API: Great for public APIs, mobile apps, third-party integrations
- SSH + WP-CLI: **Better for CI/CD and automation** (no rate limits, security blocks, or timeouts)

---

## When to Use Each Approach

### Use WordPress REST API When:
- ✅ Building public APIs for third parties
- ✅ Mobile app backends
- ✅ Client-side JavaScript interactions
- ✅ You don't have SSH access
- ✅ The hosting provider allows API traffic from your IPs

### Use SSH + WP-CLI When:
- ✅ CI/CD pipelines (GitHub Actions, GitLab CI, etc.)
- ✅ Automated content publishing from Git
- ✅ Hosting has aggressive bot protection
- ✅ You need complex operations (cache, plugins, DB)
- ✅ Performance matters (direct server is faster)
- ✅ AI agents programmatically managing content

---

## Cost-Benefit Analysis

### REST API Approach
**Time invested:** ~4 hours of troubleshooting and documentation
**Final state:** Blocked by infrastructure, unusable
**Required action:** Contact hosting support, wait for response

### SSH + WP-CLI Approach
**Time to pivot:** ~20 minutes initial test workflow
**Time to production:** ~1.5 hours (including SSH debugging)
**Final state:** ✅ Working reliably
**Ongoing maintenance:** None (standard SSH keys)

### The Lesson
Sometimes the "harder" solution (SSH) is actually **easier** than fighting infrastructure limitations. The initial REST API approach seemed simpler, but hit an insurmountable blocker. The SSH approach required more setup initially but resulted in a **more robust system**.

---

## Recommendations for Similar Projects

1. **Start with SSH + WP-CLI if:**
   - You're building CI/CD
   - The hosting is managed (SiteGround, WP Engine, etc.)
   - You need reliability over simplicity

2. **Prototype quickly:**
   - Create a read-only test workflow first
   - Verify SSH access and WP-CLI availability
   - Only then build the full publishing pipeline

3. **Document the journey:**
   - Future you (or future team members) will need to understand **why** you chose SSH over REST API
   - The git history tells the story, but an explanation document (like this) is invaluable

4. **Consider hosting implications:**
   - Managed WordPress hosts increasingly block automated API traffic
   - This trend will likely continue (more security = more blocks)
   - SSH access might be the **only reliable way** for automation going forward

---

## Conclusion

What started as a straightforward WordPress REST API integration turned into a deep dive into hosting security, infrastructure layers, and alternative approaches. The final SSH + WP-CLI solution is:

- **More reliable** (no HTTP security blocks)
- **More powerful** (full WP-CLI feature set)
- **Better for automation** (deterministic, fast, no rate limits)

While the REST API is the "official" WordPress way, **SSH + WP-CLI is the automation-first approach** that actually works in modern hosting environments with aggressive security.

The 5-hour journey from REST API to SSH was valuable: it forced a deeper understanding of how WordPress hosting infrastructure works and resulted in a more robust solution than originally envisioned.
