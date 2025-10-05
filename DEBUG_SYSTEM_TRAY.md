## Testing System Tray Functionality

### Issue 1: API Key Not Loading
The debug logs will show if the API key is being loaded properly. Look for:
```
SettingsService: Loading settings...
SettingsService: API Key is SET/NULL
```

### Issue 2: Lost Connection to Device
This happens when the app terminates instead of hiding. Here's how to debug:

#### Step 1: Test the Build
1. Run the app: `flutter run -d macos`
2. Add an API key in settings
3. Click "Minimize to System Tray"
4. Check the console logs

#### Step 2: Expected Behavior
- App should disappear but stay running
- System tray icon should appear (if supported)
- Console should show: "Window hidden successfully"
- No "Lost connection to device" message

#### Step 3: Troubleshooting
If you still get "Lost connection to device":

1. **Check Activity Monitor** on macOS:
   - Look for "myself_rephraser" in the process list
   - If it disappears, the app is actually terminating

2. **Test alternative approach**:
   - Try just minimizing the window (Cmd+M) instead of using the button
   - See if the app stays alive

3. **Debug system tray**:
   - The system tray may not work on macOS without special entitlements
   - Try running without system tray first

### Step 4: Manual Test
```bash
# Run and check logs
flutter run -d macos -v

# After minimizing, check if process is still running
ps aux | grep myself_rephraser
```

### Known Issues:
- macOS system tray requires special entitlements
- Flutter desktop apps may terminate when hidden on some systems
- "Lost connection to device" indicates the Flutter process ended

### Temporary Fix:
If system tray doesn't work, you can:
1. Use the regular minimize (Cmd+M) instead of hide
2. Keep the app in the dock
3. Use the global hotkey `Cmd+Shift+K` to access the paraphraser

The paraphraser overlay should still work with the global hotkey even if the main window is minimized!