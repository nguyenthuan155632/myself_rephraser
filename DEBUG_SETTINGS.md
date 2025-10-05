## Settings Debugging Test

To test if settings are saving/loading correctly:

### 1. Run the app
```bash
flutter run -d macos
```

### 2. Add debug prints
The app now has extensive debug logging for settings:
- SettingsService.loadSettings() - prints what's being loaded
- SettingsService.saveSettings() - prints what's being saved  
- ParaphraseProvider.updateSettings() - prints provider updates
- SettingsScreen._saveSettings() - prints UI save actions

### 3. Test this process:
1. Open app → Check console for "SettingsService: Loading settings..."
2. Go to Settings → Enter API key (e.g., "test-key-123")
3. Click Save → Check console for save logs
4. Close app completely (Cmd+Q)
5. Reopen app → Check if API key field is populated
6. Check console for load logs showing API key is "SET"

### 4. Expected console output:
```
SettingsService: Loading settings...
SettingsService: API Key is NULL
SettingsService: Model: gpt-3.5-turbo

[When saving]
Saving settings...
API Key: SET
Model: gpt-3.5-turbo
Provider: Updating settings...
SettingsService: Saving settings...
SettingsService: Saving API key to secure storage
SettingsService: All settings saved successfully

[When reloading]
SettingsService: Loading settings...
SettingsService: API Key is SET
SettingsService: Model: gpt-3.5-turbo
```

### 5. If still not working:
- Check macOS Keychain Access for app entries
- Check if there are permission errors in console
- Try removing the app and reinstalling to reset storage

The debug prints will show exactly where the issue occurs!