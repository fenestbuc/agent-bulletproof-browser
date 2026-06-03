# Notion UI Automation

Notion's web interface is deliberately resistant to browser automation. Its UI uses heavily obfuscated class names, dynamic React portals, and non-standard event handling. These notes capture workarounds discovered through hands-on automation attempts.

## The Left-Then-Right-Click Pattern for Sidebar Context Menus

**Problem:** Right-clicking a sidebar item directly often fails to open the context menu.

**Solution:** First left-click to select/focus the item, then right-click on it.

```python
# 1. Left-click to focus/select
click_at_xy(116, 281)
wait(1)

# 2. Then right-click to open context menu
click_at_xy(116, 281, button="right")
wait(2)

# 3. Verify menu opened
menu_open = js("document.body.innerText.includes('Move to')")
```

Without the initial left-click, the right-click is ignored. This applies to all sidebar items (pages, databases, favorites).

## Finding Elements in Obfuscated UIs

Notion does not use stable class names or IDs. Three approaches, in order of preference:

### 1. Accessibility Tree + DOM IDREF Bridge

The CDP accessibility tree reliably finds elements by their visible text, but the node IDs are backend-only. Bridge them to frontend DOM nodes:

```python
# Get accessibility tree
ax_tree = cdp("Accessibility.getFullAXTree")
nodes = {n["nodeId"]: n for n in ax_tree.get("nodes", [])}

# Find node by name
target = next(n for n in nodes.values()
              if "Cornerstone Projects" in str(n.get("name", {}).get("value", "")))
backend_id = target["backendDOMNodeId"]

# Push to frontend and get bounding box
cdp("DOM.enable")
result = cdp("DOM.pushNodesByBackendIdsToFrontend", backendNodeIds=[backend_id])
node_id = result["nodeIds"][0]
box = cdp("DOM.getBoxModel", nodeId=node_id)
```

**Pitfall:** `DOM.pushNodesByBackendIdsToFrontend` requires `DOM.enable` first, and the returned `nodeId` may be `0` if the element is not in the active frame.

### 2. DOM IDREF from Accessibility Tree

Some accessibility nodes expose an `idref` attribute pointing to a real DOM element:

```python
# Get idref from accessibility node properties
idref = target["properties"]["labelledby"]["value"]["relatedNodes"][0]["idref"]
# e.g., ":rk:"

# Query DOM by idref (escape colons for CSS selector)
el = js("document.getElementById(':rk:') || document.querySelector('#\\\\:rk\\\\:')")
rect = js("document.getElementById(':rk:').getBoundingClientRect()")
```

This is the most reliable way to get pixel coordinates for sidebar items.

### 3. Text-Based DOM Scan

When all else fails, scan the DOM by text content:

```python
result = js("""
Array.from(document.querySelectorAll('*'))
  .filter(el => el.textContent && el.textContent.includes('Target Text'))
  .map(el => {
    const r = el.getBoundingClientRect();
    return {tag: el.tagName, x: r.x, y: r.y, w: r.width, h: r.height};
  })
""")
```

**Pitfall:** This returns many nested elements. Filter by `children.length === 0` for leaf text nodes, or by minimum dimensions for clickable targets.

## Coordinate Grid Search Fallback

When you know a menu or popup exists but cannot query it, perform a grid search:

```python
for x in range(150, 301, 50):
    for y in range(300, 401, 20):
        click_at_xy(x, y)
        wait(0.5)
        if js("document.body.innerText.includes('Target Text')"):
            print(f"Found at x={x}, y={y}")
            break
```

This is slow but effective when React portals render outside the normal DOM hierarchy.

## Screenshot Verification Loop

Always pair automation attempts with screenshots. Notion's UI state can change asynchronously:

```python
capture_screenshot("/tmp/step_N.png")
# Analyze with vision model or manual inspection
```

## Specific Notion Behaviors

| UI Element | Automation Approach |
|------------|---------------------|
| Sidebar items | Left-click, then right-click |
| Context menu options | Grid search or keyboard navigation (ArrowDown + Enter) |
| "Move to" dialog | Opens after clicking "Move to" in context menu |
| Inline databases | Cannot be moved via API; must use UI "Move to" |
| React dropdowns | Resist `click_at_xy`; try keyboard (ArrowDown + Enter) |
| Command palette (Ctrl+Shift+P) | Often fails in headless/automated contexts |

## When to Stop Automating Notion

Notion's anti-automation design is intentional. If you have spent more than 10 minutes on a single UI interaction, consider:

1. **Using the API** for everything it supports (page creation, content blocks, database queries)
2. **Accepting manual steps** for API-unsupported operations (moving inline databases, changing view filters, reparenting pages that silently refuse API updates)
3. **Documenting the manual step** for the user rather than fighting the UI

### Specific API vs. UI boundary

| Operation | API | UI Manual |
|-----------|-----|-----------|
| Create page | Yes | Not needed |
| Add blocks | Yes | Not needed |
| Query database | Yes | Not needed |
| Update properties | Yes | Not needed |
| Reparent child database | **No** (400 error) | Required |
| Reparent page | **Unreliable** (200 but silent failure) | Required |
| Set view filters | No | Required |
| Drag-and-drop sidebar | No | Required |

The API covers ~80% of operations. The remaining 20% requires manual intervention. **Do not spend more than 10 minutes trying to automate a single Notion UI interaction.** When the API cannot do it and the UI resists two different approaches (coordinate clicking + keyboard navigation, or accessibility tree + DOM bridging), stop and ask the user to complete the step manually.