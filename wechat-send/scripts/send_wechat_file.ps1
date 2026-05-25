param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$true)][string]$ContactName,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$FilePath = (Resolve-Path $FilePath).Path
Write-Host "=== WeChat Send vFinal ==="
Write-Host "File: $FilePath | Contact: $ContactName"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class WxF {
    [DllImport("user32.dll")] public static extern bool EnumWindows(Ewp cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hw, out uint pid);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hw, StringBuilder t, int n);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hw, StringBuilder c, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hw, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hw);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hw);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hw, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hw);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hw);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dw, uint dx, uint dy, uint d, UIntPtr ex);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
    public delegate bool Ewp(IntPtr h, IntPtr p);
    public const int SW_RESTORE = 9; public const int SW_SHOW = 5;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static void Click(int x, int y) {
        SetCursorPos(x, y); System.Threading.Thread.Sleep(40);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(20);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static RECT GetRect(IntPtr hw) { RECT r; GetWindowRect(hw, out r); return r; }

    public static IntPtr FindAndRestore() {
        var allPids = new HashSet<int>();
        foreach (var p in System.Diagnostics.Process.GetProcesses()) {
            string n = p.ProcessName.ToLower();
            if (n == "weixin" || n == "wechat" || n.StartsWith("wechatapp")) allPids.Add(p.Id);
        }
        if (allPids.Count == 0) return IntPtr.Zero;

        IntPtr best = IntPtr.Zero; int bestArea = 0; string bestTitle = "";
        EnumWindows((h, lp) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (!allPids.Contains((int)pid)) return true;
            var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
            string t = sb.ToString();
            bool isWx = t.Contains("\u5fae\u4fe1") || t.Contains("WeChat") || t.Contains("Weixin");
            var sbc = new StringBuilder(256); GetClassName(h, sbc, 256);
            isWx = isWx || sbc.ToString().Contains("Qt51514QWindowIcon");
            if (!isWx) return true;
            RECT r; GetWindowRect(h, out r);
            int area = (r.R - r.L) * (r.B - r.T);
            if (area > bestArea) { bestArea = area; best = h; bestTitle = t; }
            return true;
        }, IntPtr.Zero);

        if (best == IntPtr.Zero) return IntPtr.Zero;

        RECT rr; GetWindowRect(best, out rr);
        Console.WriteLine("[WxF] Found: {0}x{1} ''{2}''", rr.R-rr.L, rr.B-rr.T, bestTitle);

        int ww = rr.R - rr.L, wh = rr.B - rr.T;
        if (ww * wh < 50000 || IsIconic(best)) {
            Console.WriteLine("[WxF] Restoring window...");
            ShowWindow(best, SW_RESTORE);
            System.Threading.Thread.Sleep(800);
            ShowWindow(best, SW_SHOW);
            System.Threading.Thread.Sleep(300);
        }

        IntPtr fg = GetForegroundWindow();
        uint ft; GetWindowThreadProcessId(fg, out ft);
        uint mt = GetCurrentThreadId();
        if (ft != 0 && ft != mt) AttachThreadInput(mt, ft, true);
        BringWindowToTop(best); System.Threading.Thread.Sleep(100);
        SetForegroundWindow(best); System.Threading.Thread.Sleep(300);
        if (ft != 0 && ft != mt) AttachThreadInput(mt, ft, false);

        return best;
    }
}

"@
Add-Type -AssemblyName System.Windows.Forms

$hwnd = [WxF]::FindAndRestore()
if ($hwnd -eq [IntPtr]::Zero) { Write-Error "WeChat not found"; exit 1 }

$r = [WxF]::GetRect($hwnd)
$ww = $r.R - $r.L; $wh = $r.B - $r.T
Write-Host "[1] WeChat: $ww x $wh at ($($r.L), $($r.T))"

# Clipboard
$fl = [System.Collections.Specialized.StringCollection]::new()
$fl.Add($FilePath) | Out-Null
[System.Windows.Forms.Clipboard]::SetFileDropList($fl)
Write-Host "[2] Clipboard OK"

# ---- SEARCH: click multiple positions + Ctrl+F ----
# Search box in WeChat PC is typically in the top-left of the left panel
# Left panel is about 200-250px wide. Title bar is ~30px.
# Try x=100px from left (center of left panel top), y=45px from top (below title bar)
$sx_a = $r.L + 100;  $sy_a = $r.T + 45
$sx_b = $r.L + 130;  $sy_b = $r.T + 48
Write-Host "[3] Click search positions: ($sx_a,$sy_a) ($sx_b,$sy_b)"
[WxF]::Click($sx_a, $sy_a); Sleep 0.2
[WxF]::Click($sx_b, $sy_b); Sleep 0.3

# Also try Ctrl+F as fallback
Write-Host "[3b] Ctrl+F"
[System.Windows.Forms.SendKeys]::SendWait("^f"); Sleep 0.4

# Type name
Write-Host "[4] Type: $ContactName"
$en = $ContactName -replace '([+^%~(){}])', '{$1}'
[System.Windows.Forms.SendKeys]::SendWait("^a"); Sleep 0.1
[System.Windows.Forms.SendKeys]::SendWait("{DEL}"); Sleep 0.1
[System.Windows.Forms.SendKeys]::SendWait($en); Sleep 2.0

# ENTER to open (no DOWN - first result should be auto-selected)
Write-Host "[5] ENTER to open chat"
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}"); Sleep 2.0

# Click input area (bottom of right panel)
$ix = $r.L + [int]($ww * 0.75)
$iy = $r.B - 60
Write-Host "[6] Click input ($ix, $iy)"
[WxF]::Click($ix, $iy); Sleep 0.5

# Msg
if ($Message) {
    $em = $Message -replace '([+^%~(){}])', '{$1}'
    [System.Windows.Forms.SendKeys]::SendWait($em); Sleep 0.4
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}"); Sleep 0.5
}

# Paste
Write-Host "[7] Ctrl+V"
[System.Windows.Forms.SendKeys]::SendWait("^v"); Sleep 2.5
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}"); Sleep 0.5

Write-Host "[DONE]" -ForegroundColor Green
