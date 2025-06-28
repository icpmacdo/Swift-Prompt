# Swift-Prompt Troubleshooting Guide

## Quick Fixes

### 🔴 Critical Issues

#### App Won't Launch
1. **Check macOS version**: Requires macOS 12.0 or later
2. **Verify app integrity**: 
   ```bash
   codesign -v /Applications/Swift-Prompt.app
   ```
3. **Reset app permissions**:
   ```bash
   tccutil reset All com.yourcompany.Swift-Prompt
   ```

#### App Crashes on Startup
1. Delete preferences:
   ```bash
   defaults delete com.yourcompany.Swift-Prompt
   ```
2. Remove app support files:
   ```bash
   rm -rf ~/Library/Application\ Support/Swift-Prompt
   ```
3. Reinstall the app

### 🟡 Common Problems

#### No Files Appearing After Folder Selection

**Symptoms:**
- Folder selected but file list is empty
- File count shows 0

**Solutions:**
1. **Check file type filter**
   - Ensure correct extensions are selected
   - Try selecting "*" to show all files

2. **Verify folder contents**
   ```bash
   ls -la /path/to/your/folder
   ```

3. **Check permissions**
   - System Preferences > Security & Privacy > Files and Folders
   - Ensure Swift-Prompt has access

#### XML Export Returns Empty String

**Symptoms:**
- "Copy With Tasks" produces no content
- Clipboard appears empty after copying

**Solutions:**
1. **Verify file aggregation**
   - Check if files are loaded (non-zero count)
   - Try "Copy Raw" first to test

2. **Check for special characters**
   - Remove emojis from tasks/warnings
   - Avoid < > & characters in file content

3. **Enable debug logging**
   - Open Console.app
   - Filter for "Swift-Prompt"
   - Look for parsing errors

#### Performance Issues

**Symptoms:**
- Slow file loading
- UI becomes unresponsive
- High memory usage

**Solutions:**
1. **Reduce file count**
   - Be specific with file type selection
   - Avoid selecting entire monorepos

2. **Check for large files**
   ```bash
   find /your/project -type f -size +10M
   ```

3. **Close background apps**
   - Free up system memory
   - Restart Swift-Prompt

### 🟢 Feature-Specific Issues

#### File Monitoring Not Working

**Symptoms:**
- Changes not detected
- No automatic refresh

**Solutions:**
1. Re-select the folder
2. Check if folder is on a network drive
3. Verify FSEvents is working:
   ```bash
   sudo fs_usage -w -f filesys | grep your_folder_name
   ```

#### Diff Preview Shows Incorrect Changes

**Symptoms:**
- Diff doesn't match expected changes
- Wrong files being compared

**Solutions:**
1. Ensure AI response format is correct
2. Check file paths match exactly
3. Verify no duplicate filenames

#### Keyboard Shortcuts Not Working

**Symptoms:**
- ⌘+O doesn't open folder dialog
- Other shortcuts unresponsive

**Solutions:**
1. Check if another app is intercepting
2. Verify in System Preferences > Keyboard > Shortcuts
3. Restart the app

## Detailed Diagnostics

### Enable Verbose Logging

Add to `~/.swiftpromptrc`:
```
SWIFT_PROMPT_DEBUG=1
SWIFT_PROMPT_LOG_LEVEL=verbose
```

### Check Security Permissions

Run this diagnostic script:
```bash
#!/bin/bash
echo "Checking Swift-Prompt permissions..."

# Check Full Disk Access
echo -n "Full Disk Access: "
if [[ -r ~/Library/Safari/Bookmarks.plist ]]; then
    echo "✓ Granted"
else
    echo "✗ Not granted"
fi

# Check file access
echo -n "Documents access: "
if [[ -r ~/Documents/ ]]; then
    echo "✓ Accessible"
else
    echo "✗ Not accessible"
fi
```

### Memory Usage Analysis

Monitor memory usage:
```bash
while true; do
    ps aux | grep Swift-Prompt | grep -v grep
    sleep 5
done
```

## Error Code Reference

| Error | Description | Solution |
|-------|-------------|----------|
| `fileNotFound` | File doesn't exist | Verify file path |
| `fileAccessDenied` | No read permission | Check file permissions |
| `pathTraversalAttempt` | Security violation | Use paths within project |
| `fileTooLarge` | File exceeds 10MB | Split file or increase limit |
| `xmlGenerationFailed` | XML creation error | Check for special characters |
| `noCodeBlocksFound` | Parser found no code | Verify AI response format |
| `bookmarkCreationFailed` | Can't save folder reference | Re-select folder |

## Platform-Specific Issues

### macOS Ventura (13.0+)
- May require additional privacy permissions
- Check System Settings > Privacy & Security

### macOS Monterey (12.0)
- Minimum supported version
- Some features may be limited

### Apple Silicon (M1/M2/M3)
- Runs natively
- No Rosetta required

## Reporting Issues

When reporting bugs, include:

1. **System Info**
   ```bash
   sw_vers
   sysctl hw.model
   ```

2. **App Version**
   - Found in Swift-Prompt > About

3. **Steps to Reproduce**
   - Exact sequence of actions
   - Sample files if possible

4. **Error Messages**
   - Screenshots
   - Console logs

5. **Expected vs Actual**
   - What should happen
   - What actually happens

## Contact Support

- GitHub Issues: [Report a bug](https://github.com/yourusername/Swift-Prompt/issues)
- Email: support@swiftprompt.app
- Discord: [Join our community](https://discord.gg/swiftprompt)

## Recovery Procedures

### Reset to Factory Settings
```bash
# Backup current settings
cp ~/Library/Preferences/com.yourcompany.Swift-Prompt.plist ~/Desktop/

# Remove all app data
rm -rf ~/Library/Application\ Support/Swift-Prompt
rm ~/Library/Preferences/com.yourcompany.Swift-Prompt.plist

# Restart app
```

### Restore Backed-up Files
All file modifications create timestamped backups:
```bash
# List backups
ls -la *.backup-*

# Restore a backup
cp file.swift.backup-1234567890 file.swift
```

---

Remember: Most issues can be resolved by:
1. Restarting the app
2. Re-selecting the folder
3. Checking permissions