---
name: wechat-send
description: Send files to WeChat contacts on Windows by automating the WeChat desktop client. Finds the WeChat window via EnumWindows, restores it from tray if needed, clicks the search box, types the contact name, opens the chat, and pastes the file. Use when the user needs to send a file to a specific WeChat contact through the Windows WeChat desktop app.
---

# WeChat File Sender

Sends files to WeChat contacts by automating the Windows WeChat desktop client.

## How It Works

1. Enumerates all windows of Weixin/WeChat processes to find the main window
2. Restores the window if minimized/collapsed
3. Activates the window using AttachThreadInput + SetForegroundWindow
4. Clicks the search box area and presses Ctrl+F as fallback
5. Types the contact name and presses Enter to open the chat
6. Clicks the chat input area
7. Pastes the file via Ctrl+V and presses Enter to send

## Prerequisites

- Windows with WeChat desktop client installed and logged in
- WeChat window may be minimized, the script restores it automatically
- The target contact must exist in the contact list

## Usage

```powershell
.\scripts\send_wechat_file.ps1 -FilePath "<full-path>" -ContactName "<contact-name>" [-Message "<optional-message>"]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-FilePath` | Yes | Full path to the file to send |
| `-ContactName` | Yes | Display name or remark name of the contact |
| `-Message` | No | Optional text message to send alongside the file |

### Examples

```powershell
.\scripts\send_wechat_file.ps1 -FilePath "C:\Users\xu\Desktop\report.pdf" -ContactName "Zhang San"
.\scripts\send_wechat_file.ps1 -FilePath "C:\Photos\vacation.jpg" -ContactName "Mom" -Message "Check this out!"
```

## Important Notes

- Do not touch the keyboard or mouse while the script is running
- The script uses mouse clicks and simulated keystrokes
- If the search does not find the contact, verify the exact display/remark name in WeChat
- The window position is read dynamically, moving the WeChat window between runs is fine

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| WeChat not found | WeChat not running | Start WeChat and log in |
| Wrong chat opened | Search found a different contact | Verify exact contact name |
| File not pasted | Input area not focused | Increase sleep durations |
