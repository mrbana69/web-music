# Web Music - Crossfade/Song Change Fix

## Approved Plan Steps (4 steps)

### [ ] Step 1: Create TODO.md ✅ (Current)

### [ ] Step 2: Fix playTrack() audio reset & load sequence
- Add nativeAudio.load() after src change
- nativeAudio.pause(); currentTime=0 before src=
- try/catch nativeAudio.play() with error toast

### [ ] Step 3: Ensure nextTrack() awaits fadeOut completion  
- await fadeOut(player, 0.8) before playTrackFromQueue()

### [ ] Step 4: Add audio error listener + test
- nativeAudio.onerror → nextTrack() + toast
- Test full sequence: play → next → fade → new song

## 🎵 **Expected Result**
Previous: fadeout → silence  
**Fixed**: fadeout → immediate new song (clean src/load/play)

Progress tracked here. Step 2 next.
