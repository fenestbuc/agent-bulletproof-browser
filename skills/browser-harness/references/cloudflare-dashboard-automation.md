# Cloudflare Dashboard Automation Quirks

Session: 2026-05-06. Attempting to create an API token via browser-harness on dash.cloudflare.com.

## Outcome

Failed to complete token creation. The permission template loaded, but the Account Resources custom dropdown could not be opened via CDP automation. User was directed to `wrangler login` or manual dashboard flow instead.

## What works

- Navigating to `https://dash.cloudflare.com/profile/api-tokens`
- Clicking "Create Token"
- Selecting a template (e.g., "Edit Cloudflare Workers")
- The permission rows populate automatically

## What does NOT work

### Custom React dropdowns

Cloudflare uses framework-managed select components for:
- Account Resources ("Select..." dropdown)
- Zone Resources ("Specific zone" dropdown)

These have `aria-haspopup="listbox"` and visually look like native selects, but:
- `click_at_xy()` on the dropdown trigger does not open the listbox
- `js()` `.click()` on the element does not open the listbox
- No `<select>` or `<option>` elements exist in the DOM; options are rendered via React portal or custom listbox

**Do not waste time trying multiple click strategies.** This is a known dead end.

### Obfuscated selectors

All UI elements use generated class names (e.g., `c_di c_fo c_dk c_dl`). There are no stable `data-testid` or semantic selectors. The only reliable element targeting is text-content matching via `js()`:

```python
js("""Array.from(document.querySelectorAll('*')).filter(
    e => e.textContent && e.textContent.trim() === 'Edit Cloudflare Workers'
).map(e => ({x: e.getBoundingClientRect().x, y: e.getBoundingClientRect().y}))""")
```

## Recommended alternative paths

### 1. Direct token entry (fastest and most reliable)

When a token already exists or the user can create one manually, skip wrangler OAuth entirely:

```bash
# Verify the token first
curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer <TOKEN>"

# Save to wrangler config
mkdir -p ~/.config/.wrangler/config
cat > ~/.config/.wrangler/config/default.toml << EOF
api_token = "<TOKEN>"
EOF
chmod 600 ~/.config/.wrangler/config/default.toml

# Or use via env var (no file needed)
CLOUDFLARE_API_TOKEN="<TOKEN>" wrangler whoami
```

Also add to `~/.hermes/.env` so Hermes picks it up:
```bash
echo 'CLOUDFLARE_API_TOKEN="<TOKEN>"' >> ~/.hermes/.env
```

### 2. **`wrangler login --browser=false`** (CLI OAuth)

Generates a URL for the user to open and approve. **Often fails silently:**
- The OAuth URL opens in the user's browser
- User approves the grant
- The callback goes to `localhost:8976`
- If wrangler's background listener misses the callback (firewall, port conflict, process killed), auth remains broken
- `wrangler whoami` still returns "You are not authenticated"

**When this happens, fall back to direct token entry immediately.** Do not retry `wrangler login` multiple times.

### 3. **Manual token creation**
- User goes to dash.cloudflare.com/profile/api-tokens
- Selects template, picks account, creates token
- Pastes token string to the agent

### 4. **Existing token reuse**
- If the user already has a valid token, just paste it

## Account context

- Account ID: `2b5cbebc5575c078926c3f4e5efd5267`
- Previous token prefix: `cfut_S5ZnPZ...` (Workers Scripts:Edit scope)
- Previous token prefix: `cfut_CH93NNW...` (also Workers-scoped)
