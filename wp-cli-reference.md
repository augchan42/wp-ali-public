# WP-CLI Command Reference

This document contains the WordPress CLI commands used for managing WordPress sites via SSH.

**Note:** Replace placeholders with actual values from `secrets/actual-values.md` (if available) or your own configuration.

## SSH Connection

```bash
ssh -p 18765 user@ssh.yourdomain.com
cd /home/username/www.yourdomain.com/public_html
```

## Page Management

### List all pages
```bash
wp post list --post_type=page --format=table
```

### List pages with specific fields
```bash
wp post list --post_type=page --fields=ID,post_title,post_name,post_status --format=table
```

### Search for pages by slug pattern
```bash
wp post list --post_type=page --name__like=speaker --fields=ID,post_title,post_name,post_status --format=table
```

### Get full page details
```bash
wp post get 119635
```

### Get specific page fields
```bash
wp post get 119635 --fields=post_status,post_modified,post_date --format=json
```

### Get only page content
```bash
wp post get 119635 --field=post_content
```

### Create a new page
```bash
wp post create \
  --post_type=page \
  --post_title='Speaker' \
  --post_name='speaker' \
  --post_content='<p>Page content here</p>' \
  --post_status=publish \
  --porcelain
```

### Update existing page
```bash
# Update title
wp post update 119635 --post_title="Speaker Bio"

# Update slug
wp post update 119635 --post_name='speaker'

# Update content
wp post update 119635 --post_content='<p>New content</p>'

# Update multiple fields
wp post update 119635 \
  --post_title='Speaker Bio' \
  --post_content='<p>Updated content</p>' \
  --post_status=publish
```

### Delete a page
```bash
# Soft delete (move to trash)
wp post delete 119635

# Hard delete (permanent)
wp post delete 119635 --force
```

## Menu Management

### List all menus
```bash
wp menu list
```

### List menu items for a specific menu
```bash
# Menu ID 288 is "Top Menu" (primary navigation)
wp menu item list 288
```

### List menu items with formatted table
```bash
wp menu item list 288 --format=table
```

### Search menu items
```bash
wp menu item list 288 | grep Speaker
```

### Add page to menu
```bash
wp menu item add-post 288 119639 --title="Speaker Bio" --position=8
```

### Update menu item
```bash
# Update URL
wp menu item update 119637 --url="https://yourdomain.com/speaker/"

# Update title
wp menu item update 119637 --title="Speaker Bio"
```

### Delete menu item
```bash
wp menu item delete 119637
```

## Plugin Management

### List all active plugins
```bash
wp plugin list --status=active --format=table
```

### List all plugins
```bash
wp plugin list
```

## Cache Management

### Flush WordPress object cache
```bash
wp cache flush
```

### Delete all transients
```bash
wp transient delete --all
```

### Flush rewrite rules
```bash
wp rewrite flush
```

### Update permalink structure
```bash
wp option update permalink_structure '/%postname%/'
```

**Note:** These commands only flush WordPress-level cache. SiteGround's Dynamic Cache must be cleared from Site Tools UI:
- Go to https://tools.siteground.com
- Speed → Caching → Flush Cache

## WP-CLI Information

### Check WP-CLI version and environment
```bash
wp --info
```

## Common Workflows

### Update page content from local markdown file
```bash
# Convert markdown to HTML locally
python3 << 'EOF'
import markdown
content = open('pages/speaker.md').read()
html = markdown.markdown(content)
print(html)
EOF

# Then update via SSH
ssh -p 18765 user@ssh.yourdomain.com \
  "cd /home/username/www.yourdomain.com/public_html && \
   wp post update 119635 --post_content='<p>Escaped HTML here</p>'"
```

### Check if page exists before creating
```bash
page_id=$(wp post list --post_type=page --name='speaker-bio' --field=ID --format=csv 2>/dev/null | head -n1)

if [ -n "$page_id" ] && [ "$page_id" != "ID" ]; then
  echo "Page exists: $page_id"
  wp post update $page_id --post_title="New Title"
else
  echo "Page doesn't exist, creating..."
  wp post create --post_type=page --post_title="Speaker Bio" --post_name="speaker-bio" --porcelain
fi
```

## Useful JSON Queries with jq

### Get page count
```bash
wp post list --post_type=page --format=json | jq 'length'
```

### Extract specific field from JSON
```bash
wp post get 119635 --format=json | jq -r '.post_title'
```

### Filter pages by status
```bash
wp post list --post_type=page --format=json | jq '.[] | select(.post_status=="publish")'
```

## Page IDs Reference

- **119635**: Original Speaker Bio page (deleted)
- **119639**: Current Speaker page (slug: `speaker`)
- **288**: Top Menu (primary navigation)
- **119640**: Speaker menu item (position 5, after Workshops)

## Common Issues

### Permission denied on SSH
Make sure your SSH key is added to the agent:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Changes not appearing on live site
SiteGround Dynamic Cache needs manual flushing from Site Tools UI.

### Slug conflicts
WordPress auto-increments slugs if there's a conflict (e.g., `speaker` becomes `speaker-2`). Always check for existing pages before creating new ones.
