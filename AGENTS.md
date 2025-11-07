# Repository Guidelines

## Project Structure & Module Organization
The `pages/` directory holds publishable Markdown pages; each filename becomes the page slug, so prefer kebab-case like `speaker-bio.md`. GitHub Actions configuration lives in `.github/workflows/publish-wordpress.yml`, which is the only automation entry point. Temporary artifacts such as `out.json` are generated during publishing—do not commit them. Keep any helper scripts under a new `scripts/` directory if needed so the workflow remains uncluttered.

## Build, Test, and Development Commands
Run the same conversion that CI performs before pushing:
```bash
python3 -m pip install --upgrade pip markdown jq
python3 - <<'PY'
import glob, json, pathlib, markdown
pages = [
    {
        "title": pathlib.Path(p).stem,
        "slug": pathlib.Path(p).stem.lower().replace(" ", "-"),
        "content": markdown.markdown(open(p, encoding="utf-8").read()),
    }
    for p in glob.glob("pages/**/*.md", recursive=True)
]
open("out.json", "w", encoding="utf-8").write(json.dumps(pages, ensure_ascii=False, indent=2))
print(f"Prepared {len(pages)} page(s) for publishing")
PY
jq 'length' out.json
```

Test SSH connection locally:
```bash
ssh -p 18765 user@ssh.host.com "cd /path/to/wordpress && wp post list --post_type=page"
```

Use `gh workflow run "Publish WordPress Pages"` to trigger the deployment manually after confirming secrets are set.

## Coding Style & Naming Conventions
Write Markdown with a single `#` heading at the top, concise sections, and GitHub-flavored tables or lists when needed. Keep prose in US English, wrap lines at ~100 characters, and avoid trailing whitespace. File names should be lowercase with hyphens; embedded images should reference absolute URLs because local assets are not synced.

## Testing Guidelines
Before committing, render Markdown locally (e.g., in VS Code preview) to catch layout issues. Validate generated JSON with `jq empty out.json` and ensure every page has a unique slug. If a page depends on shortcodes or embedded HTML, test it in a staging WordPress instance, since CI cannot verify runtime rendering.

## Commit & Pull Request Guidelines
Follow the existing history by using imperative, capitalized summaries (e.g., “Enhance WordPress publishing workflow …”) under 72 characters when possible. Group related changes per commit. Pull requests should include: purpose summary, impacted pages, any manual verification notes, and screenshots or links showing the published result when UI-visible changes ship.

## Security & Configuration Tips
Update SSH secrets (`SITEGROUND_SSH_HOST`, `SITEGROUND_SSH_USER`, `SITEGROUND_SSH_KEY`, `SITEGROUND_SSH_PASSPHRASE`, `SITEGROUND_WP_PATH`) via the repository settings; never commit credentials or print them in logs. Rotate SSH keys if a leak is suspected, and scrub sensitive data from `out.json` before sharing debug files. The workflow uses SSH key-based authentication for secure, automated deployments that bypass HTTP/API security layers.
