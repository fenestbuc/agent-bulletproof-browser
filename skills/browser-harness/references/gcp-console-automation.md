# GCP Console Automation Quirks

Session: 2026-05-06. Attempting to generate a new GCP service account key via browser-harness on console.cloud.google.com.

## Outcome

Failed due to Google bot detection blocking automated interactions after repeated CDP events. The browser session reached the service account Keys page and clicked "Add key," but a subsequent automation block prevented completing the flow. User was directed to manual dashboard creation or `gcloud` CLI instead.

## What works

- Navigating to `https://console.cloud.google.com/iam-admin/serviceaccounts?project=<PROJECT>&authuser=<N>`
- Listing service accounts (text extraction via `js()`)
- Navigating to a specific service account details page
- Clicking the "Keys" tab

## What does NOT work

### Bot detection after repeated interactions

Google Cloud Console has aggressive automation detection. After ~10-15 CDP interactions (clicks, navigations, text extractions) within a short window, the console may display:

> "Google has temporarily blocked your account or network due to excessive automated requests"

This block appears as a banner in the console UI and may persist for hours. Once triggered, all further automation on GCP console pages fails.

**Mitigation:** Keep GCP console interactions minimal. If you need more than 3-4 clicks, switch to the `gcloud` CLI or ask the user to complete the action manually.

### Custom React components (similar to Cloudflare)

The "Add key" button triggers a menu that does not open reliably via CDP clicks:
- `click_at_xy()` on the button registers visually but the menu portal does not render
- `js()` `.click()` on the element behaves the same way
- No `[role=menu]` or dropdown DOM elements appear after clicking

This is the same class of problem as Cloudflare's custom dropdowns: framework-managed components that bypass native browser event dispatch.

### Account/project switching

GCP Console URLs support `authuser=N` and `project=<PROJECT>` query parameters, but:
- The `authuser` index maps to the Google account's position in the signed-in account list, which changes
- If the wrong authuser is selected, the page may show access denied errors
- The project picker may reset to a default project unexpectedly

**Safer approach:** Navigate directly to the target URL with both parameters set, then verify the page title contains the expected project name.

## Recommended alternative paths

### 1. Manual dashboard creation (fastest and most reliable)

User completes the flow in their browser:
1. Go to console.cloud.google.com/iam-admin/serviceaccounts
2. Select project (if not already active)
3. Click the service account (e.g., `hermesagent@kubar-protocol-main.iam.gserviceaccount.com`)
4. Keys tab -> Add key -> Create new key -> JSON
5. Download the JSON file
6. Copy to `~/.hermes/gcp_service_account.json`
7. Run `chmod 600 ~/.hermes/gcp_service_account.json`

### 2. `gcloud` CLI with manual OAuth

When the user has `gcloud` installed but auth is expired:

```bash
# This generates a URL for the user to approve
gcloud auth login --no-launch-browser

# User opens the URL in their browser, completes OAuth, copies the auth code
# Paste the code back into the terminal

# Verify login
gcloud auth list

# Create a new service account key
gcloud iam service-accounts keys create ~/.hermes/gcp_service_account.json \
  --iam-account=hermesagent@kubar-protocol-main.iam.gserviceaccount.com
```

**Pitfall:** The `--no-launch-browser` flow requires an interactive terminal to paste the auth code. If the agent is running in a non-interactive shell, the process hangs waiting for stdin. Use `gcloud auth activate-service-account` with an existing key file instead, or have the user run the command directly.

### 3. Direct key file replacement

If the user already has a valid service account JSON key downloaded:

```bash
cp /path/to/downloaded/key.json ~/.hermes/gcp_service_account.json
chmod 600 ~/.hermes/gcp_service_account.json
```

Verify the key works:

```bash
# Via gcloud
gcloud auth activate-service-account \
  --key-file=~/.hermes/gcp_service_account.json

# Or via Python JWT test
python3 -c "
import json, jwt, time
with open('/home/yash/.hermes/gcp_service_account.json') as f:
    sa = json.load(f)
now = int(time.time())
claim = {
    'iss': sa['client_email'],
    'sub': sa['client_email'],
    'scope': 'https://www.googleapis.com/auth/cloud-platform',
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': now,
    'exp': now + 3600
}
token = jwt.encode(claim, sa['private_key'], algorithm='RS256')
print(token)
"
```

## Account context

- Project: `kubar-protocol-main`
- Service Account: `hermesagent@kubar-protocol-main.iam.gserviceaccount.com`
- Service Account ID: `107657602068431738799`
- Key locations:
  - Primary: `~/.hermes/gcp_service_account.json`
  - gcloud legacy: `~/.config/gcloud/legacy_credentials/hermesagent@kubar-protocol-main.iam.gserviceaccount.com/adc.json`
