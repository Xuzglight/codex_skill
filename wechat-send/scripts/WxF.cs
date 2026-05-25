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
