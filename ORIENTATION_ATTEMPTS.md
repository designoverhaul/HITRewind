# Orientation Change Attempts for Paywall

## Goal
Display paywall in portrait mode, then return to landscape when dismissed.

## Attempt 1: Flag + setNeedsUpdate + asyncAfter + requestGeometryUpdate
**Approach:**
- Set `isPaywallShowing = true`
- Call `setNeedsUpdateOfSupportedInterfaceOrientations()`
- Use `asyncAfter(0.1s)` delay
- Call `requestGeometryUpdate(.portrait)`

**Result:** Did not rotate to portrait

---

## Attempt 2: Flag + setNeedsUpdate + asyncAfter + requestGeometryUpdate (longer delays)
**Approach:**
- Same as above but with 0.3s delays
- Used async `Superwall.register` to wait for dismissal

**Result:** Did not return to landscape after dismiss

---

## Attempt 3: Aggressive multi-method approach
**Result:** Did not work - too complicated

---

## Attempt 4: Simple approach with KEY delay after paywall dismiss ✅ SOLVED
**Insight:** Portrait switch works, but landscape return fails because paywall VC is still animating out

**Solution:**
1. Set flag → setNeedsUpdate → asyncAfter(0.15s) → requestGeometryUpdate
2. **KEY FIX: Wait 1.0 second** AFTER `Superwall.register()` returns before calling lockToLandscape
3. This gives iOS time to fully dismiss the paywall view controller animation

**Final Timeline:**
- switchToPortrait → wait 0.4s → show paywall
- paywall dismissed → **wait 1.0s** → lockToLandscape → wait 0.4s → continue

**Important Xcode Setting:**
- Keep Portrait CHECKED in Deployment Info (so iOS allows portrait when we need it)
- AppDelegate's `supportedInterfaceOrientationsFor` controls runtime behavior via OrientationManager

**Status:** ✅ FIXED

---

## Attempt 4: Present custom VC with orientation override (if Attempt 3 fails)
**Approach:**
- Create a UIHostingController subclass that overrides `supportedInterfaceOrientations`
- Present it modally before showing paywall
- This forces iOS to respect our orientation

---

## Attempt 5: Superwall configuration (if needed)
**Approach:**
- Check if Superwall SDK has orientation settings
- Configure paywall presentation style

---

## Notes
- iOS 16+ changed how orientation works significantly
- `requestGeometryUpdate` is the new API but can be finicky
- AppDelegate's `supportedInterfaceOrientationsFor` must return the orientation we want
- The flag must be set BEFORE calling setNeedsUpdate
