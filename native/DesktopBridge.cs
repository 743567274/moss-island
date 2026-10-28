using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Accessibility;
using System.Globalization;

// External, narrowly scoped .NET Framework helper. Farm logic lives in GDScript.
class DesktopBridge {
    delegate IntPtr MouseProc(int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, MouseProc callback, IntPtr module, uint thread);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook,int code,IntPtr message,IntPtr data);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] static extern bool IsChild(IntPtr parent,IntPtr child);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out Rect r);
    [DllImport("oleacc.dll")] static extern int AccessibleObjectFromWindow(IntPtr h,uint objectId,ref Guid iid,[MarshalAs(UnmanagedType.Interface)] out IAccessible accessible);
    [StructLayout(LayoutKind.Sequential)] struct MouseData { public Point P; public uint Data,Flags,Time; public UIntPtr Extra; }
    static MouseProc mouseCallback=Mouse;
    static IntPtr mouseHook, icons, shellRoot;
    static System.Collections.Generic.List<Rect> iconRects=new System.Collections.Generic.List<Rect>();
    static bool iconsValid;
    static int heldButtons;
    static int passedButtons;
    static DateTime nextIconRefresh=DateTime.MinValue;
    static StringBuilder inputQueue=new StringBuilder();
    static int attachmentCount;
    static IntPtr patchedWorker;
    static long workerOriginalStyle;
    static bool pointerAvailable;
    static void QueueInput(int message, Point screen, int buttons, int wheel) {
        Rect client; if(!GetClientRect(window,out client) || client.R<=0 || client.B<=0) return;
        Point local=screen; MapWindowPoints(IntPtr.Zero,window,ref local,1);
        inputQueue.Append(message).Append('|')
            .Append(((double)local.X/client.R).ToString("R",CultureInfo.InvariantCulture)).Append('|')
            .Append(((double)local.Y/client.B).ToString("R",CultureInfo.InvariantCulture)).Append('|')
            .Append(buttons).Append('|').Append(wheel).Append('\n');
    }
    static void FlushInput() {
        if(inputQueue.Length==0) return;
        try {
            File.AppendAllText(Path.Combine(folder,"input-events"),inputQueue.ToString(),new UTF8Encoding(false));
            inputQueue.Length=0;
        } catch(IOException) {}
    }
    static void RefreshIcons() {
        var fresh=new System.Collections.Generic.List<Rect>();
        IntPtr list=FindWindowEx(icons,IntPtr.Zero,"SysListView32",null);
        if(list==IntPtr.Zero) { iconsValid=false; return; }
        if(!IsWindowVisible(list)) { iconRects=fresh; iconsValid=true; return; }
        IntPtr count;
        if(SendMessageTimeout(list,0x1004,IntPtr.Zero,IntPtr.Zero,2,100,out count)==IntPtr.Zero) { iconsValid=false; return; }
        IAccessible acc; Guid iid=new Guid("618736e0-3c3d-11cf-810c-00aa00389b71");
        if(AccessibleObjectFromWindow(list,0xFFFFFFFC,ref iid,out acc)!=0) { iconsValid=false; return; }
        try {
            for(int i=1;i<=count.ToInt32();i++) {
                int x,y,w,h; acc.accLocation(out x,out y,out w,out h,i);
                if(w<=0 || h<=0) { iconsValid=false; return; }
                fresh.Add(new Rect { L=x,T=y,R=x+w,B=y+h });
            }
            iconRects=fresh; iconsValid=true;
        } catch(COMException) { iconsValid=false; } finally { Marshal.ReleaseComObject(acc); }
    }
    static bool Contains(Rect r,Point p) { return p.X>=r.L && p.X<r.R && p.Y>=r.T && p.Y<r.B; }
    static IntPtr Mouse(int code,IntPtr message,IntPtr data) {
        if(code<0 || !desktop || suspended || locked) return CallNextHookEx(mouseHook,code,message,data);
        MouseData m=(MouseData)Marshal.PtrToStructure(data,typeof(MouseData));
        int msg=message.ToInt32();
        bool release=msg==0x202 || msg==0x208;
        int bit=(msg==0x201 || msg==0x202)?1:((msg==0x207 || msg==0x208)?16:0);
        if(release && (passedButtons&bit)!=0) { passedButtons&=~bit; return CallNextHookEx(mouseHook,code,message,data); }
        IntPtr hit=WindowFromPoint(m.P);
        bool available=Contains(monitorRect,m.P) && (hit==window || hit==worker || hit==shellRoot || hit==icons || IsChild(icons,hit));
        if(heldButtons==0) {
            if(!iconsValid) available=false;
            foreach(Rect rect in iconRects) if(Contains(rect,m.P)) available=false;
        }
        if((!available || passedButtons!=0) && !(release && heldButtons!=0)) {
            if(pointerAvailable && heldButtons==0) {
                inputQueue.Append("0|0|0|0|0\n"); pointerAvailable=false;
            }
            if(!release) passedButtons|=bit;
            return CallNextHookEx(mouseHook,code,message,data);
        }
        if(msg!=0x200 && msg!=0x201 && msg!=0x202 && msg!=0x207 && msg!=0x208 && msg!=0x20A)
            return CallNextHookEx(mouseHook,code,message,data);
        pointerAvailable=true;
        if(msg==0x201) heldButtons|=1;
        if(msg==0x207) heldButtons|=16;
        if(msg==0x202) heldButtons&=~1;
        if(msg==0x208) heldButtons&=~16;
        QueueInput(msg,m.P,heldButtons,msg==0x20A?(short)(m.Data>>16):0);
        return msg==0x200?CallNextHookEx(mouseHook,code,message,data):new IntPtr(1);
    }
    [DllImport("user32.dll")] static extern IntPtr FindWindow(string cls, string name);
    [DllImport("user32.dll")] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string name);
    delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint command);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder text, int count);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetLong(IntPtr h, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] static extern IntPtr SetLong(IntPtr h, int index, IntPtr value);
    [DllImport("user32.dll", SetLastError=true)] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int he, uint flags);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect rect);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    static bool IsCovered(IntPtr target) {
        IntPtr front=GetForegroundWindow();
        if(front==IntPtr.Zero || front==target || !IsWindowVisible(front)) return false;
        uint targetPid, frontPid;
        GetWindowThreadProcessId(target,out targetPid); GetWindowThreadProcessId(front,out frontPid);
        if(targetPid==frontPid) return false; // Settings/testing windows must stay live.
        var cls=new StringBuilder(128); GetClassName(front,cls,128);
        if(cls.ToString()=="Progman" || cls.ToString()=="WorkerW" || cls.ToString()=="Shell_TrayWnd") return false;
        Rect r; if(!GetWindowRect(front,out r)) return false;
        var area=Screen.FromHandle(target).WorkingArea;
        return r.L<=area.Left+8 && r.T<=area.Top+8 && r.R>=area.Right-8 && r.B>=area.Bottom-8;
    }
    static void ReportVisibility(bool covered) {
        try {
            string temp=Path.Combine(folder,"visibility.tmp"), dest=Path.Combine(folder,"visibility");
            File.WriteAllText(temp,covered?"covered":"visible");
            if(File.Exists(dest)) File.Replace(temp,dest,null); else File.Move(temp,dest);
        } catch(IOException) {}
    }
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool PeekMessage(out Msg msg, IntPtr h, uint min, uint max, uint remove);
    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorProc callback, IntPtr data);
    [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")] static extern int MapWindowPoints(IntPtr from, IntPtr to, ref Point point, uint count);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr target);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="GetMonitorInfoW")] static extern bool GetMonitorInfoEx(IntPtr monitor,ref MonitorInfoEx info);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string device,int mode,ref DisplayMode info);
    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern IntPtr RegisterPowerSettingNotification(IntPtr handle, ref Guid guid, uint flags);
    [DllImport("user32.dll")] static extern bool UnregisterPowerSettingNotification(IntPtr handle);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref Msg msg);
    delegate bool MonitorProc(IntPtr h, IntPtr dc, ref Rect rect, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X,Y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int L,T,R,B; }
    [StructLayout(LayoutKind.Sequential)] struct MonitorInfo { public int Size; public Rect Bounds, Work; public uint Flags; }
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct MonitorInfoEx { public int Size; public Rect Bounds,Work; public uint Flags; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string Device; }
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct DisplayMode {
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string Device;
        public ushort Spec,Driver,Size,Extra; public uint Fields; public int X,Y; public uint Orientation,FixedOutput;
        public short Color,Duplex,YResolution,TTOption,Collate;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string Form;
        public ushort LogPixels; public uint Bits,Width,Height,Flags,Frequency,ICMMethod,ICMIntent,MediaType,DitherType,Reserved1,Reserved2,PanningWidth,PanningHeight;
    }
    [StructLayout(LayoutKind.Sequential)] struct Msg { public IntPtr H; public uint Message; public UIntPtr W; public IntPtr L; public uint Time; public Point P; public uint Private; }
    static IntPtr window, originalParent, worker;
    static long originalStyle, originalEx;
    static Rect originalRect, monitorRect;
    static string folder;
    static bool desktop, locked, suspended;
    static int monitorIndex;
    const long WS_CHILD=0x40000000L, WS_POPUP=0x80000000L, WS_TRANSPARENT=0x20L, WS_TOOLWINDOW=0x80L;
    class PowerWindow : NativeWindow, IDisposable {
        IntPtr registration;
        public PowerWindow() {
            var parameters=new CreateParams(); parameters.Caption="MossIsland Power";
            parameters.ExStyle=(int)WS_TOOLWINDOW;
            CreateHandle(parameters);
            var guid=new Guid("6fe69556-704a-47a0-8f24-c28d936fda47");
            registration=RegisterPowerSettingNotification(Handle,ref guid,0);
        }
        protected override void WndProc(ref Message m) {
            if(m.Msg==0x218) {
                long code=m.WParam.ToInt64();
                if(code==4) ReportPower(false);
                else if(code==7 || code==18) ReportPower(true);
                else if(code==0x8013 && Marshal.ReadInt32(m.LParam,16)==4)
                    ReportPower(Marshal.ReadInt32(m.LParam,20)!=0);
            }
            base.WndProc(ref m);
        }
        public void Dispose() {
            if(registration!=IntPtr.Zero) UnregisterPowerSettingNotification(registration);
            DestroyHandle();
        }
    }
    static void ReportPower(bool active) {
        try { File.WriteAllText(Path.Combine(folder,"power.tmp"),active?"on":"off");
            string dest=Path.Combine(folder,"power");
            if(File.Exists(dest)) File.Replace(Path.Combine(folder,"power.tmp"),dest,null);
            else File.Move(Path.Combine(folder,"power.tmp"),dest);
        } catch(IOException) {}
    }

    static void DumpShell(IntPtr target,int depth) {
        var cls=new StringBuilder(128); GetClassName(target,cls,128);
        Rect r; GetWindowRect(target,out r);
        Console.WriteLine(new string(' ',depth*2)+"Hwnd="+target+" Class="+cls+" Visible="+IsWindowVisible(target)+" Style="+GetLong(target,-16).ToInt64()+" Ex="+GetLong(target,-20).ToInt64()+" Rect="+r.L+","+r.T+","+r.R+","+r.B);
        if(depth>=3) return;
        IntPtr child=IntPtr.Zero;
        while((child=FindWindowEx(target,child,null,null))!=IntPtr.Zero) DumpShell(child,depth+1);
    }
    static IntPtr DesktopWorker(bool create=true) {
        IntPtr progman=FindWindow("Progman",null), result;
        shellRoot=progman;
        IntPtr previousIcons=icons;
        icons=IntPtr.Zero;
        if(progman==IntPtr.Zero) return IntPtr.Zero;
        if(create) SendMessageTimeout(progman,0x052C,IntPtr.Zero,IntPtr.Zero,2,1000,out result);
        IntPtr found=IntPtr.Zero;
        EnumWindows(delegate(IntPtr h,IntPtr p) {
            if(FindWindowEx(h,IntPtr.Zero,"SHELLDLL_DefView",null)!=IntPtr.Zero) {
                icons=FindWindowEx(h,IntPtr.Zero,"SHELLDLL_DefView",null);
                // Windows 11 24H2 hosts the wallpaper WorkerW under Progman.
                IntPtr child=FindWindowEx(h,IntPtr.Zero,"WorkerW",null);
                found=child!=IntPtr.Zero?child:FindWindowEx(IntPtr.Zero,h,"WorkerW",null);
            }
            return true;
        },IntPtr.Zero);
        if(icons!=previousIcons) { iconsValid=false; iconRects.Clear(); }
        // Do not expose a renderer while Explorer is still constructing its icon view.
        Rect bounds;
        if(icons==IntPtr.Zero || !IsWindowVisible(icons)
            || FindWindowEx(icons,IntPtr.Zero,"SysListView32",null)==IntPtr.Zero
            || FindWindow("Shell_TrayWnd",null)==IntPtr.Zero
            || !GetClientRect(icons,out bounds) || bounds.R<=0 || bounds.B<=0) return IntPtr.Zero;
        // Raised desktop (Win11 24H2+): use Progman as the GPU host and
        // place our child immediately below ShellView, above wallpaper WorkerW.
        // A child of WorkerW can be attached yet never composited on this layout.
        if(found!=IntPtr.Zero && GetParent(icons)==progman && (GetLong(progman,-20).ToInt64() & 0x00200000L)!=0) return progman;
        if(found!=IntPtr.Zero && GetParent(found)!=IntPtr.Zero) return IntPtr.Zero;
        return found;
    }
    static bool Precedes(IntPtr above,IntPtr below) {
        // GW_HWNDPREV walks only siblings, from the wallpaper towards the top.
        for(IntPtr h=GetWindow(below,3);h!=IntPtr.Zero;h=GetWindow(h,3))
            if(h==above) return true;
        return false;
    }
    static long DesktopExStyle() {
        return (originalEx & ~0x40000L & ~0x8L)|WS_TRANSPARENT|WS_TOOLWINDOW|0x08000000L;
    }
    static void SuspendDesktop() {
        if(mouseHook!=IntPtr.Zero) { UnhookWindowsHookEx(mouseHook); mouseHook=IntPtr.Zero; }
        heldButtons=0; passedButtons=0; pointerAvailable=false;
        inputQueue.Length=0; inputQueue.Append("0|0|0|0|0\n");
        ShowWindow(window,0);
        if(!suspended) Report("waiting-for-desktop");
        suspended=true;
    }
    static bool KeepBelowIcons() {
        if(worker==IntPtr.Zero || !IsWindow(worker) || !IsWindow(icons) || GetParent(window)!=worker) return false;
        long style=GetLong(window,-16).ToInt64();
        long desiredStyle=(style & ~WS_POPUP & ~0x00CF0000L)|WS_CHILD|0x04000000L;
        long desiredEx=DesktopExStyle();
        bool changed=style!=desiredStyle || GetLong(window,-20).ToInt64()!=desiredEx;
        if(style!=desiredStyle) SetLong(window,-16,new IntPtr(desiredStyle));
        if(GetLong(window,-20).ToInt64()!=desiredEx) SetLong(window,-20,new IntPtr(desiredEx));
        bool wrongOrder=worker==shellRoot && (GetParent(icons)!=worker || !Precedes(icons,window));
        if(worker==shellRoot && GetParent(icons)!=worker) return false;
        if(changed || wrongOrder) {
            IntPtr after=worker==shellRoot?icons:new IntPtr(1);
            if(!SetWindowPos(window,after,0,0,0,0,0x1|0x2|0x10|0x20|0x200)) return false;
        }
        return worker!=shellRoot || Precedes(icons,window);
    }
    static System.Collections.Generic.List<Rect> Monitors() {
        var list=new System.Collections.Generic.List<Rect>();
        EnumDisplayMonitors(IntPtr.Zero,IntPtr.Zero,delegate(IntPtr h,IntPtr dc,ref Rect r,IntPtr p) {
            MonitorInfo info=new MonitorInfo(); info.Size=Marshal.SizeOf(info);
            if(GetMonitorInfo(h,ref info)) list.Add(info.Bounds);
            return true;
        },IntPtr.Zero);
        return list;
    }
    static void DisplayReport() {
        EnumDisplayMonitors(IntPtr.Zero,IntPtr.Zero,delegate(IntPtr h,IntPtr dc,ref Rect r,IntPtr p) {
            MonitorInfoEx info=new MonitorInfoEx(); info.Size=Marshal.SizeOf(info); GetMonitorInfoEx(h,ref info);
            DisplayMode mode=new DisplayMode(); mode.Size=(ushort)Marshal.SizeOf(mode); EnumDisplaySettings(info.Device,-1,ref mode);
            Console.WriteLine("Device="+info.Device+" Bounds="+info.Bounds.L+","+info.Bounds.T+","+info.Bounds.R+","+info.Bounds.B+" Mode="+mode.X+","+mode.Y+","+mode.Width+","+mode.Height);
            return true;
        },IntPtr.Zero);
    }
    static void Report(string state) {
        try { File.WriteAllText(Path.Combine(folder,"input-status"),"Hook="+(mouseHook!=IntPtr.Zero)+" Icons="+iconsValid+" Attachments="+attachmentCount); } catch(IOException) {}
        try { File.WriteAllText(Path.Combine(folder,"status.tmp"),DateTime.UtcNow.Ticks+"|"+state,Encoding.UTF8);
            string dest=Path.Combine(folder,"status");
            if(File.Exists(dest)) File.Replace(Path.Combine(folder,"status.tmp"),dest,null);
            else File.Move(Path.Combine(folder,"status.tmp"),dest);
        } catch(IOException) {}
    }
    static void Restore(bool show=true) {
        if(mouseHook!=IntPtr.Zero) { UnhookWindowsHookEx(mouseHook); mouseHook=IntPtr.Zero; }
        if(!IsWindow(window)) return;
        if(!show) ShowWindow(window,0);
        SetParent(window,originalParent);
        SetLong(window,-16,new IntPtr(originalStyle));
        SetLong(window,-20,new IntPtr(originalEx));
        SetWindowPos(window,IntPtr.Zero,originalRect.L,originalRect.T,originalRect.R-originalRect.L,originalRect.B-originalRect.T,0x20|0x10|(show?0x40u:0u));
        if(show) ShowWindow(window,4); desktop=false; locked=false;
        if(patchedWorker!=IntPtr.Zero && IsWindow(patchedWorker) && GetLong(patchedWorker,-16).ToInt64()==(workerOriginalStyle|0x02000000L))
            SetLong(patchedWorker,-16,new IntPtr(workerOriginalStyle));
        patchedWorker=IntPtr.Zero;
    }
    static void SetLocked(bool value) {
        if(!desktop) return;
        // Once attached, locking is an input-only transition. Reparenting or refreshing
        // the frame here can recreate Godot's swapchain and briefly expose a black desktop.
        Rect current; GetWindowRect(window,out current);
        bool needsAttach=suspended || worker==IntPtr.Zero || !IsWindow(worker) || GetParent(window)!=worker
            || current.L!=monitorRect.L || current.T!=monitorRect.T || current.R!=monitorRect.R || current.B!=monitorRect.B;
        if(needsAttach) {
            worker=DesktopWorker();
            if(worker==IntPtr.Zero) { locked=value; SuspendDesktop(); return; }
            // The raised desktop host must clip its GPU-rendered child area.
            // Only patch on attachment; lock/unlock remains input-only.
            if((GetLong(worker,-16).ToInt64() & 0x02000000L)==0) {
                patchedWorker=worker; workerOriginalStyle=GetLong(worker,-16).ToInt64();
                SetLong(worker,-16,new IntPtr(workerOriginalStyle|0x02000000L));
            }
            SetLong(window,-16,new IntPtr((originalStyle & ~WS_POPUP & ~0x00CF0000L)|WS_CHILD|0x04000000L));
            // --wid may initially set an owner rather than a WS_CHILD parent.
            // GetParent returns both; always commit parenting after child style.
            SetParent(window,worker);
            SetLong(window,-20,new IntPtr(DesktopExStyle()));
            Point point=new Point(); point.X=monitorRect.L; point.Y=monitorRect.T;
            MapWindowPoints(IntPtr.Zero,worker,ref point,1);
            if(!SetWindowPos(window,worker==shellRoot && icons!=IntPtr.Zero?icons:IntPtr.Zero,point.X,point.Y,monitorRect.R-monitorRect.L,monitorRect.B-monitorRect.T,0x20|0x40|0x10)
                || GetParent(window)!=worker) { locked=value; SuspendDesktop(); return; }
            SetWindowPos(worker,IntPtr.Zero,0,0,0,0,0x20|0x10|0x1|0x2|0x4);
            // Raised desktop ShellView caches the old wallpaper surface. Refresh
            // its composition once after attaching, never on lock/unlock.
            if((worker==shellRoot || GetParent(worker)==shellRoot) && icons!=IntPtr.Zero && IsWindowVisible(icons)) {
                ShowWindow(icons,0);
                ShowWindow(icons,4);
            }
            // Commit after resizing: Godot may refresh EXSTYLE while handling WM_SIZE.
            SetLong(window,-20,new IntPtr(DesktopExStyle()));
            attachmentCount++;
        }
        if(!KeepBelowIcons()) { locked=value; SuspendDesktop(); return; }
        suspended=false;
        if(value && !locked) inputQueue.Append("0|0|0|0|0\n");
        locked=value; heldButtons=0; passedButtons=0;
        pointerAvailable=false;
        if(value) {
            try {
                string path=Path.Combine(folder,"input-events");
                if(File.Exists(path) && new FileInfo(path).Length>2097152) File.WriteAllText(path,"");
            } catch(IOException) {}
        }
        if(mouseHook!=IntPtr.Zero) { UnhookWindowsHookEx(mouseHook); mouseHook=IntPtr.Zero; }
        if(!value) {
            RefreshIcons();
            mouseHook=SetWindowsHookEx(14,mouseCallback,GetModuleHandle(null),0);
            if(mouseHook==IntPtr.Zero) { locked=true; Report("error:Desktop input hook failed"); return; }
        }
        Report(value?"locked":"unlocked");
    }
    [STAThread] static int Main(string[] args) {
        if(!SetProcessDpiAwarenessContext(new IntPtr(-4))) SetProcessDPIAware();
        SetThreadDpiAwarenessContext(new IntPtr(-4));
        if(args.Length==1 && args[0]=="--display-report") { DisplayReport(); return 0; }
        if(args.Length==1 && args[0]=="--desktop-host") { Console.WriteLine(DesktopWorker().ToInt64()); return 0; }
        if(args.Length==2 && args[0]=="--inspect") {
            IntPtr target=new IntPtr(long.Parse(args[1])); Rect bounds; GetWindowRect(target,out bounds);
            Point center=new Point(); center.X=(bounds.L+bounds.R)/2; center.Y=(bounds.T+bounds.B)/2;
            Rect client; GetClientRect(target,out client);
            Console.WriteLine("Client="+client.R+","+client.B+" Style="+GetLong(target,-16).ToInt64()+" Parent="+GetParent(target)+" ExpectedWorker="+DesktopWorker(false)+" Bounds="+bounds.L+","+bounds.T+","+bounds.R+","+bounds.B+" ExStyle="+GetLong(target,-20).ToInt64()+" Window="+target+" HitAtCenter="+WindowFromPoint(center)+" Covered="+IsCovered(target));
            return 0;
        }
        if(args.Length==1 && args[0]=="--probe") {
            Console.WriteLine("Explorer="+FindWindow("Progman",null)+" WorkerW="+DesktopWorker()+" Monitors="+Monitors().Count);
            EnumWindows(delegate(IntPtr h,IntPtr p) {
                var name=new StringBuilder(256); GetClassName(h,name,256);
                if(name.ToString()=="Progman" || name.ToString()=="WorkerW") {
                    DumpShell(h,0);
                }
                return true;
            },IntPtr.Zero);
            return 0;
        }
        if(args.Length<3) return 2;
        window=new IntPtr(long.Parse(args[0])); folder=args[1]; int parentPid=int.Parse(args[2]);
        int controllerPid=args.Length>=4?int.Parse(args[3]):0;
        Directory.CreateDirectory(folder);
        GetWindowRect(window,out originalRect); originalParent=GetParent(window);
        originalStyle=GetLong(window,-16).ToInt64(); originalEx=GetLong(window,-20).ToInt64();
        string previous=""; bool running=true; DateTime nextCommandPoll=DateTime.MinValue;
        File.WriteAllText(Path.Combine(folder,"input-events"),"");
        DateTime nextHousekeeping=DateTime.MinValue; bool? coveredState=null;
        PowerWindow powerWindow=new PowerWindow();
        Report("ready");
        try {
            while(running && IsWindow(window)) {
                if(DateTime.UtcNow>=nextHousekeeping) {
                    nextHousekeeping=DateTime.UtcNow.AddSeconds(1);
                    try {
                        using(var parent=Process.GetProcessById(parentPid)) { if(parent.HasExited) break; }
                        if(controllerPid>0) using(var controller=Process.GetProcessById(controllerPid)) { if(controller.HasExited) break; }
                    } catch(ArgumentException) { break; }
                    if(desktop) {
                        IntPtr expected=DesktopWorker(false);
                        if(expected==IntPtr.Zero) SuspendDesktop();
                        else if(suspended || expected!=worker || GetParent(window)!=expected) {
                            // A recreated Explorer view invalidates both parenting and Z-order.
                            suspended=true;
                            SetLocked(locked);
                        } else if(!KeepBelowIcons()) SuspendDesktop();
                        var displays=Monitors();
                        if(monitorIndex<displays.Count) {
                            var bounds=displays[monitorIndex]; Rect actual; GetWindowRect(window,out actual);
                            if(bounds.L!=monitorRect.L || bounds.T!=monitorRect.T || bounds.R!=monitorRect.R || bounds.B!=monitorRect.B || actual.L!=bounds.L || actual.T!=bounds.T || actual.R!=bounds.R || actual.B!=bounds.B) {
                                monitorRect=bounds; SetLocked(locked);
                            }
                        }
                    }
                    bool covered=IsCovered(window);
                    if(!coveredState.HasValue || coveredState.Value!=covered) {
                        coveredState=covered; ReportVisibility(covered);
                    }
                }
                Msg msg;
                while(PeekMessage(out msg,IntPtr.Zero,0,0,1)) {
                    DispatchMessage(ref msg);
                }
                string cmdPath=Path.Combine(folder,"command");
                string command="";
                if(DateTime.UtcNow>=nextCommandPoll) {
                    nextCommandPoll=DateTime.UtcNow.AddMilliseconds(120);
                    try { if(File.Exists(cmdPath)) command=File.ReadAllText(cmdPath).Trim(); } catch(IOException) {}
                }
                if(command!=previous && command.Length>0) {
                    previous=command; string[] parts=command.Split('|');
                    string action=parts[1];
                    if(action=="enter") {
                        if(!desktop) {
                            GetWindowRect(window,out originalRect); originalParent=GetParent(window);
                            originalStyle=GetLong(window,-16).ToInt64(); originalEx=GetLong(window,-20).ToInt64();
                        }
                        var monitors=Monitors(); int index=int.Parse(parts[2]);
                        if(index<0 || index>=monitors.Count) { Report("error:Monitor unavailable"); continue; }
                        monitorIndex=index; monitorRect=monitors[index]; desktop=true; SetLocked(true);
                    } else if(action=="lock") SetLocked(true);
                    else if(action=="unlock") SetLocked(false);
                    else if(action=="browse") { Restore(); Report("browse"); }
                    else if(action=="test-input" && desktop && !locked && parts.Length>=4) {
                        // Diagnostic delivery to our renderer only, without moving the system cursor.
                        int x=int.Parse(parts[2]), y=int.Parse(parts[3]);
                        Point screen=new Point { X=x,Y=y }; MapWindowPoints(window,IntPtr.Zero,ref screen,1);
                        int count=parts.Length>=5?Math.Max(1,Math.Min(100,int.Parse(parts[4]))):1;
                        for(int i=0;i<count;i++) {
                            QueueInput(0x200,screen,0,0);
                            QueueInput(0x201,screen,1,0);
                            QueueInput(0x202,screen,0,0);
                        }
                    }
                    else if(action=="quit") running=false;
                }
                if(desktop && !suspended && !locked && DateTime.UtcNow>=nextIconRefresh) {
                    RefreshIcons(); nextIconRefresh=DateTime.UtcNow.AddSeconds(1);
                }
                FlushInput();
                Thread.Sleep(desktop && !locked?8:150);
            }
        } catch(Exception e) { Report("error:"+e.GetType().Name); }
        finally { if(desktop) Restore(false); powerWindow.Dispose(); }
        return 0;
    }
}
