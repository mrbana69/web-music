# Search Display Fix + Additional Issues - Implementation Plan

## Current Progress (from original TODO.md)
- ✅ Step 1: Create TODO.md (done)

## Detailed Implementation Steps

**Step 2: Create this detailed TODO-steps.md** ⬇️ **NOW**

**Step 3: Fix SEARCH DISPLAY (index.html)** ✅
- Add comprehensive debug logging to search handler ✓
- Robust `items` extraction for ALL API formats ✓  
- Safe fallbacks in `createCard()`, `createAlbumCard()`, `createArtistCard()` ✓
- Test: Artist ("The Weeknd"), Album ("Abbey Road"), Track ("Blinding Lights")

**Step 4: Fix PLAYLIST PLAY BUTTON ALIGNMENT (index.html)**
- `#playlistPlayBtn` - align play icon vertically center with text
- Adjust padding/margins/line-height for perfect iPhone alignment

**Step 5: Fix iOS LOCKSCREEN ISSUE (index.html + sw.js)**
- Strengthen MediaSessionMetadata with proper artwork URLs
- Add iOS-specific MediaSession handlers (play/pause/seek)
- Improve background audio persistence (wakeLock + visibilitychange)
- SW: Ensure MediaSession events propagate correctly

**Step 6: Test All Fixes**
```
- Desktop: Search all types ✓ Playlist button ✓
- iPhone: Test lockscreen song changes ✓ Background play ✓
```

**Step 7: User verification + debug cleanup**  
**Step 8: Update TODO files → attempt_completion** ✅

## Progress Tracking
✅ Step 3: Search fixes  
[ ] Step 4: Playlist button  
[ ] Step 5: iOS lockscreen  
[ ] Step 6: Testing complete  


