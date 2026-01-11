# Xcode Setup Steps - NEW Videos Tab

## ⚠️ CRITICAL: Add Files to Xcode Project First

**You MUST add these 3 files to Xcode before building:**

### Step-by-Step Instructions

1. **Open Xcode Project**
   - Open `HIt Rewind2.xcodeproj`

2. **Add VideoModel.swift**
   - In Xcode's left sidebar (Project Navigator), right-click on the **Models** folder
   - Select **"Add Files to 'HIt Rewind2'..."**
   - Navigate to: `HIt Rewind2/Models/VideoModel.swift`
   - **IMPORTANT**: Check ✅ "Copy items if needed"
   - **IMPORTANT**: Check ✅ "HIt Rewind2" under "Add to targets"
   - Click **Add**

3. **Add DirectVideoService.swift**
   - Right-click on the **Services** folder
   - Select **"Add Files to 'HIt Rewind2'..."**
   - Navigate to: `HIt Rewind2/Services/DirectVideoService.swift`
   - **IMPORTANT**: Check ✅ "Copy items if needed"
   - **IMPORTANT**: Check ✅ "HIt Rewind2" under "Add to targets"
   - Click **Add**

4. **Add NEWVideosView.swift**
   - Right-click on the **Views/MusicVideos** folder
   - Select **"Add Files to 'HIt Rewind2'..."**
   - Navigate to: `HIt Rewind2/Views/MusicVideos/NEWVideosView.swift`
   - **IMPORTANT**: Check ✅ "Copy items if needed"
   - **IMPORTANT**: Check ✅ "HIt Rewind2" under "Add to targets"
   - Click **Add**

5. **Verify Files Added**
   - In Project Navigator, check that all 3 files appear in their respective folders
   - Files should NOT have gray icons (that means they're not in the target)
   - Click on each file and check "Target Membership" in the right sidebar
   - Ensure "HIt Rewind2" has a checkmark ✅

6. **Build the Project**
   - Press **Cmd+B** to build
   - Fix any remaining errors (should be clean now)

7. **Run on Simulator or Device**
   - Select a simulator or connected device
   - Press **Cmd+R** to run
   - Look for the **NEW** tab (✨ sparkles icon)

## Expected Build Status

After adding files, you should see:
- ✅ **0 errors**
- ⚠️ Maybe 1 warning about unused catch block (harmless)

## Troubleshooting

### "Cannot find type 'DirectVideoRecord' in scope"
**Solution**: VideoModel.swift is not added to the Xcode project. Follow Step 2 above.

### "Cannot find type 'DirectVideoService' in scope"
**Solution**: DirectVideoService.swift is not added to the Xcode project. Follow Step 3 above.

### File appears gray in Project Navigator
**Solution**:
1. Click on the gray file
2. In the right sidebar, under "Target Membership"
3. Check ✅ "HIt Rewind2"

### "No such module 'SuperwallKit'"
**Solution**: This is normal if you haven't run `pod install` or Swift Package Manager. The app uses SuperwallKit for paywalls. If missing, install via CocoaPods or SPM.

## Testing Checklist

Once the app builds and runs:

- [ ] NEW tab appears in tab bar (between MTV and AirPlay)
- [ ] Tap NEW tab → app doesn't crash
- [ ] Year sidebar shows years 2000-2020
- [ ] Select a year → videos load and display
- [ ] Each year shows ~75 videos
- [ ] Video thumbnails load correctly
- [ ] Tap a video → video player opens
- [ ] Video plays with full controls
- [ ] Video info shows correctly (title, artist, year)
- [ ] Autoplay works when video ends
- [ ] Layout is responsive on iPad
- [ ] No console errors

## Success Indicators

**Console should show**:
```
📅 NEW - Year selected: 2020
✅ Fetched 76 videos from MTvVideosNEW for year 2020
🎵 Found 76 videos for year 2020 in MTvVideosNEW
```

**UI should show**:
- NEW tab with sparkles icon (✨)
- "NEW Music Videos 2020" header with Beta badge
- "76 videos from MTvVideosNEW" subtitle
- Grid of video thumbnails with titles and artists
- Year sidebar with selectable years

## Need Help?

Check the main documentation: `NEW_VIDEOS_IMPLEMENTATION.md`
