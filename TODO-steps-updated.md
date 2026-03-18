# Search Display Fix + Alignment + iOS Lockscreen - IMPLEMENTATION PLAN (APPROVED)

## Current Progress
- ✅ Step 1: Create TODO.md  
- ✅ Step 2: TODO-steps.md  
- ✅ Step 3: Search fixes (debug logging + robust v2.6 parsing)  
- 🔧 **Step 4: Fix playlist button alignment** ← **NOW**  
- 🔧 **Step 5: iOS lockscreen fixes**  
- ⏳ Step 6: Testing  
- ✅ Step 7: User verification  
- ⏳ Step 8: Final cleanup + completion  

## PRIORITY 1: Fix JavaScript Syntax Error (BLOCKER)
**File**: index.html ~lines 2283-2295  
**Issue**: Broken `if-else` chain in search handler (missing `}` before `if (state.searchType === 'artist')`)  
**Linter**: `'try' expected`, `'catch' expected`  
**Impact**: VSCode errors, potential runtime failure  

```
**EDIT 1**: Add missing closing brace `}` after album rendering block
```

## Step 4: Playlist Play Button Alignment Fix
**File**: index.html (line ~650)  
**Target**: `#playlistPlayBtn` inline styles  
**Current**: `display:flex !important; align-items:center !important; ...`  
**Fix**: Perfect iPhone centering (`line-height:1.2; padding:16px 30px; height:52px;`)

## Step 5: iOS Lockscreen + Background Audio
**Files**: index.html (MediaSession), sw.js  
**index.html**:
1. Enhanced `updateMediaSession()`: iOS seek handlers + multiple artwork sizes  
2. Background persistence: `audioContext` + `visibilitychange` + wakeLock heartbeat  
**sw.js**: MediaSession proxy + fetch retry  

## Testing Commands (Post-Edits)
```
$ python3 -m http.server 8000
# Test 1: iPhone Simulator → Playlist button alignment
# Test 2: Search "The Weeknd" (artist/album/track filters)
# Test 3: Lockscreen → Play/pause/seek → Background audio
```

## Completion Criteria
- [ ] ✅ Syntax errors fixed  
- [ ] ✅ Playlist button perfectly centered  
- [ ] ✅ iOS lockscreen fully functional  
- [ ] ✅ Tests passed  
- [ ] 🔄 attempt_completion

**Ready to execute Step 1 (syntax fix) → Step 4 → Step 5**
