# Fork Status and Maintenance

## Current Status

| Metric | Value |
|--------|-------|
| **Fork Version** | v0.4 |
| **Based on Upstream** | Dino commit `53b52b04` (March 2026) |
| **Commits Ahead** | 14 (our features) |
| **Commits Behind** | 3 (upstream bug fixes) |
| **Last Updated** | March 27, 2026 |

## Features Added in This Fork

### v0.4 - Hover/Click Positioning Fix (Current)
- Fixed mouse hover detection offset at zoomed levels
- Reactions emoji buttons now appear below messages (not inline)
- Merged messages properly aligned without double indentation
- Changed from CSS `calc()` to GTK `margin_*` properties for layout
- Documentation: This fix resolves GTK allocation mismatch with CSS scaling

### v0.3 - Read Receipt Positioning Fix
- Fixed read receipt checkmarks appearing on separate lines for merged messages
- Checkmarks now appear directly after message text using horizontal Box layout
- Increased checkmark size to 20px for better visibility
- Documentation: `READ_RECEIPTS_FEATURE.md`, `READ_RECEIPTS_IMPLEMENTATION.md`

### v0.2 - Read Receipt Indicators
- Visual indicators for message delivery and read status (XEP-0333)
- Single tick (✓) = Sent
- Double tick (✓✓) = Delivered/Read (hover for tooltip distinction)
- "Read up to this point" bar at bottom of conversation
- Works in 1-on-1 chats with XEP-0333-capable clients

### v0.1 - Text/UI Zoom Feature
- Keyboard shortcuts: `Ctrl++`, `Ctrl+-`, `Ctrl+0`
- Scales all UI elements (text, avatars, spacing, reactions, etc.)
- Font size persists across restarts
- Resizable sidebar (drag right edge)
- Addresses [upstream issue #978](https://github.com/dino/dino/issues/978)

## Upstream Divergence

### Why We're Behind

This fork diverged from upstream Dino to add custom features. Upstream continues to receive bug fixes that are not yet incorporated into our fork.

**Current upstream commits we're missing:**

| Commit | Description | Files Changed | Priority |
|--------|-------------|---------------|----------|
| `0b92ee2a` | Fix wrongly using message ids for MUC corrections | 7 files | Medium |
| `cf352dbf` | Fix /me rendering in quotes | 2 files | Low |
| `6322365d` | Fix setting 'to' attribute in reply stanza | 1 file | Low |

### Impact of Being Behind

**Low Risk:** The 3 missing upstream commits fix edge cases:
- MUC message correction handling (uses occupant IDs properly)
- `/me` messages in quote blocks
- Reply stanza `to` attribute

These are unlikely to affect typical 1-on-1 chat usage with read receipts and zoom features.

**No Immediate Action Required** - Our features work correctly.

## Future Maintenance Options

### Option 1: Leave As-Is (Current)
**Pros:**
- Stable, working features
- No risk of breaking changes
- Minimal maintenance

**Cons:**
- Missing upstream bug fixes
- May drift further behind over time

### Option 2: Rebase on Upstream
**When to consider:**
- Upstream adds features we want
- Missing bug fixes become critical
- Preparing for major feature additions

**Command:**
```bash
git fetch upstream
git rebase upstream/master
```

**Expected effort:** 1-2 hours
- Resolve conflicts in `message_correction.vala` (HIGH risk)
- Resolve conflicts in `message_processor.vala` (MEDIUM risk)
- Test MUC corrections, quotes, replies
- Verify read receipts and zoom still work

**Conflict-prone files:**
1. `libdino/src/service/message_correction.vala` - Both branches modified MUC correction logic
2. `libdino/src/service/message_processor.vala` - Reply handling changes
3. `libdino/src/service/message_storage.vala` - Database schema changes

### Option 3: Merge Upstream
**Alternative to rebase:**
```bash
git fetch upstream
git merge upstream/master
```

**Pros:** Preserves our commit history clearly
**Cons:** Creates merge commit, same conflict resolution needed

## Recommended Maintenance Schedule

| Frequency | Action |
|-----------|--------|
| **Monthly** | Check upstream for critical bug fixes |
| **Quarterly** | Evaluate if rebase is worthwhile |
| **As Needed** | Rebase before adding major new features |

## Building from Source

```bash
# Configure
meson setup build

# Compile
meson compile -C build

# Run
./build/main/dino
```

## Reporting Issues

When reporting bugs, please specify:
1. Which feature is affected (zoom, read receipts, or base Dino)
2. Whether it reproduces in upstream Dino (if known)
3. Dino version: `./build/main/dino --version`

## Upstream Resources

- **Official Dino:** https://github.com/dino/dino
- **Website:** https://dino.im/
- **Upstream Issues:** https://github.com/dino/dino/issues

## This Fork

- **Repository:** https://github.com/venus-fire/dino
- **Releases:** https://github.com/venus-fire/dino/releases
- **Feature Documentation:**
  - `README.md` - Overview of all features
  - `ZOOM_FEATURE_DOCUMENTATION.md` - Text zoom feature details
  - `READ_RECEIPTS_FEATURE.md` - Read receipts user guide
  - `READ_RECEIPTS_IMPLEMENTATION.md` - Read receipts technical docs
  - `QWEN.md` - Development context and conventions

---

**Last Updated:** March 26, 2026  
**Maintainer:** venus-fire
