using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Device.Location;
using System.Net;
using System.Collections.Generic;
using System.Web.Script.Serialization;

// This process owns Windows lifecycle only. All farm data stays in the renderer's GDScript core.
class TrayHost : ApplicationContext {
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int pid);
    readonly string root=AppDomain.CurrentDomain.BaseDirectory;
    readonly string data=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Godot","app_userdata","苔屿 · 桌面微观农场");
    NotifyIcon tray;
    System.Windows.Forms.Timer timer;
    Process renderer;
    string mode="immersive", lastRequest="";
    bool quitting, switching, locked=true;
    DateTime switchStarted;
    ToolStripMenuItem lockItem;
    int locating;
    bool launchPending;
    DateTime nextLaunch, launchDeadline;
    string StartupCommand { get { return "\""+Application.ExecutablePath+"\" --startup"; } }
    string ControlDir { get { return Path.Combine(data,"host"); } }

    [STAThread] static int Main(string[] args) {
        Application.EnableVisualStyles();
        bool first;
        using(var mutex=new Mutex(true,"Local\\MossIslandTrayHost_v2",out first)) {
            if(!first) {
                string dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Godot","app_userdata","苔屿 · 桌面微观农场","host");
                if(args.Length>0 && args[0].StartsWith("--command=")) WriteAtomic(Path.Combine(dir,"host_request"),DateTime.UtcNow.Ticks+"|"+args[0].Substring(10));
                else if(args.Length>0 && args[0].StartsWith("--mode=")) WriteAtomic(Path.Combine(dir,"host_request"),DateTime.UtcNow.Ticks+"|"+args[0].Substring(7));
                else WriteAtomic(Path.Combine(dir,"host_request"),DateTime.UtcNow.Ticks+"|immersive");
                return 0;
            }
            // A command invocation without a running tray must never launch a renderer.
            if(args.Length>0 && args[0].StartsWith("--command=")) return 0;
            Application.Run(new TrayHost(args));
        }
        return 0;
    }
    static void WriteAtomic(string path,string text) {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        File.WriteAllText(path+".tmp",text,new System.Text.UTF8Encoding(false));
        if(File.Exists(path)) File.Replace(path+".tmp",path,null);
        else File.Move(path+".tmp",path);
    }
    void SeedBundledData() {
        // Distribution content is copied once into a new user's writable data.
        // Never replace existing projects, plant packages or farm progress.
        string seed=Path.Combine(root,"initial-data");
        string marker=Path.Combine(data,"bundle-initialized.txt");
        if(!Directory.Exists(seed) || File.Exists(marker)) return;
        string projects=Path.Combine(data,"maps","projects");
        string pending=Path.Combine(data,"bundle-installing.txt");
        if(!File.Exists(pending) && (File.Exists(Path.Combine(data,"farm.json")) ||
           File.Exists(Path.Combine(data,"maps","active-project.json")) ||
           File.Exists(Path.Combine(data,"crop-editor","index.json")) ||
           (Directory.Exists(projects) && Directory.GetFiles(projects,"project.json",SearchOption.AllDirectories).Length>0))) return;
        Directory.CreateDirectory(data);
        File.WriteAllText(pending,"Bundled content initialization in progress.");
        foreach(string file in Directory.GetFiles(seed,"*",SearchOption.AllDirectories)) {
            string relative=file.Substring(seed.Length).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
            string destination=Path.GetFullPath(Path.Combine(data,relative));
            if(!destination.StartsWith(Path.GetFullPath(data)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Invalid bundled content path.");
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            if(!File.Exists(destination)) File.Copy(file,destination,false);
        }
        File.WriteAllText(marker,DateTime.UtcNow.ToString("o"),new System.Text.UTF8Encoding(false));
        File.Delete(pending);
    }
    TrayHost(string[] args) {
        SeedBundledData();
        Directory.CreateDirectory(ControlDir);
        RegisterDesktopSettings();
        File.Delete(Path.Combine(ControlDir,"host_request"));
        tray=new NotifyIcon(); tray.Text="苔屿 · 微缩山水庭院"; tray.Icon=MakeIcon();
        var menu=new ContextMenuStrip();
        lockItem=(ToolStripMenuItem)menu.Items.Add("解锁桌面",null,delegate { ToggleLock(); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("设置",null,delegate { Send("settings"); });
        menu.Items.Add("地图编辑器",null,delegate { Send("map_editor"); });
        menu.Items.Add("作物编辑器",null,delegate { Send("crop_editor"); });
        menu.Items.Add("仓库",null,delegate { Send("collection"); });
        menu.Items.Add("重新获取定位",null,delegate { Send("request_location"); });
        menu.Items.Add("测试",null,delegate { Send("environment_test"); });
        menu.Items.Add(new ToolStripSeparator());
        var startup=(ToolStripMenuItem)menu.Items.Add("开机自启");
        using(var key=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")) {
            startup.Checked=key.GetValue("MossIsland")!=null;
            if(startup.Checked) key.SetValue("MossIsland",StartupCommand);
        }
        startup.Click+=delegate {
            using(var key=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")) {
                if(startup.Checked) key.DeleteValue("MossIsland",false);
                else key.SetValue("MossIsland",StartupCommand);
                startup.Checked=!startup.Checked;
            }
        };
        menu.Items.Add("存档目录",null,delegate { Process.Start("explorer.exe",data); });
        menu.Items.Add("官网",null,delegate {
            try {
                Process.Start(new ProcessStartInfo("https://www.gongjudengta.top/article/224") { UseShellExecute=true });
            } catch(Exception) {
                tray.ShowBalloonTip(5000,"无法打开官网","请使用浏览器访问：https://www.gongjudengta.top/article/224",ToolTipIcon.Warning);
            }
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("保存并退出",null,delegate { quitting=true; BeginStop(); });
        tray.ContextMenuStrip=menu;
        tray.DoubleClick+=delegate { Send("settings"); };
        tray.Visible=true;
        timer=new System.Windows.Forms.Timer(); timer.Interval=250; timer.Tick+=Tick; timer.Start();
        ScheduleLaunch(args.Length>0 && args[0]=="--startup"?3000:0);
        if(!File.Exists(Path.Combine(data,"welcome-shown"))) {
            tray.ShowBalloonTip(7000,"苔屿已在桌面安家","右键托盘叶片图标解锁农场。解锁后使用右上角背包播种、铲子收获、水壶浇水。",ToolTipIcon.Info);
            File.WriteAllText(Path.Combine(data,"welcome-shown"),"1");
        }
    }

    void RegisterDesktopSettings() {
        // Per-user desktop background menu, without replacing Explorer's menu.
        try {
            using(var key=Registry.CurrentUser.CreateSubKey(@"Software\Classes\DesktopBackground\Shell\MossIslandSettings")) {
                key.SetValue("", "苔屿设置");
                key.SetValue("Icon", Application.ExecutablePath);
                using(var command=key.CreateSubKey("command"))
                    command.SetValue("", "\""+Application.ExecutablePath+"\" --command=settings");
            }
        } catch(Exception error) {
            File.AppendAllText(Path.Combine(ControlDir,"desktop-menu.log"),error.Message+Environment.NewLine);
        }
    }
    static Icon MakeIcon() {
        using(var bitmap=new Bitmap(32,32)) {
            using(var graphics=Graphics.FromImage(bitmap)) {
                graphics.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                graphics.Clear(Color.Transparent);
                graphics.FillEllipse(new SolidBrush(Color.FromArgb(48,74,57)),1,1,30,30);
                graphics.FillEllipse(new SolidBrush(Color.FromArgb(184,199,139)),9,5,9,17);
                graphics.FillEllipse(new SolidBrush(Color.FromArgb(151,179,114)),17,10,9,13);
                graphics.DrawLine(new Pen(Color.Beige,2),15,14,14,26);
            }
            return Icon.FromHandle(bitmap.GetHicon());
        }
    }
    void RequestLocation(bool automatic=false) {
        if(Interlocked.CompareExchange(ref locating,1,0)!=0) return;
        var requestedAt=DateTime.UtcNow;
        if(!automatic) tray.ShowBalloonTip(4000,"正在自动定位","优先获取 Windows 位置，失败后尝试 IP 估算位置。",ToolTipIcon.Info);
        ThreadPool.QueueUserWorkItem(delegate {
            try {
                using(var watcher=new GeoCoordinateWatcher(GeoPositionAccuracy.High)) {
                    GeoPosition<GeoCoordinate> best=null;
                    watcher.TryStart(false,TimeSpan.FromSeconds(10));
                    while((DateTime.UtcNow-requestedAt).TotalSeconds<22) {
                        var fix=watcher.Position;
                        var point=fix.Location;
                        if(!point.IsUnknown && !Double.IsNaN(point.HorizontalAccuracy) && !Double.IsInfinity(point.HorizontalAccuracy)
                           && (DateTimeOffset.UtcNow-fix.Timestamp).TotalMinutes<5
                           && (best==null || point.HorizontalAccuracy<best.Location.HorizontalAccuracy)) best=fix;
                        if(best!=null && best.Location.HorizontalAccuracy<=300) break;
                        if(watcher.Permission==GeoPositionPermission.Denied) break;
                        Thread.Sleep(250);
                    }
                    if(best!=null) {
                        var point=best.Location;
                        var culture=System.Globalization.CultureInfo.InvariantCulture;
                        var epoch=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc);
                        Send("location|"+point.Latitude.ToString("R",culture)+"|"+point.Longitude.ToString("R",culture)+"|"+point.HorizontalAccuracy.ToString("R",culture)+"|"+(best.Timestamp.UtcDateTime-epoch).TotalSeconds.ToString("R",culture)+"|"+(requestedAt-epoch).TotalSeconds.ToString("R",culture));
                    } else FetchIpLocation(requestedAt);
                }
            } catch(Exception) { FetchIpLocation(requestedAt); }
            finally { Interlocked.Exchange(ref locating,0); }
        });
    }
    class LocationClient : WebClient {
        protected override WebRequest GetWebRequest(Uri address) {
            var request=base.GetWebRequest(address); request.Timeout=8000;
            var http=request as HttpWebRequest;
            if(http!=null) http.ReadWriteTimeout=8000;
            return request;
        }
    }
    internal static bool ParseIpLocation(string json,out double lat,out double lon) {
        lat=lon=0;
        try {
            var result=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(json);
            if(result==null || (result.ContainsKey("success") && !Convert.ToBoolean(result["success"])) || (result.ContainsKey("error") && Convert.ToBoolean(result["error"]))) return false;
            string country=result.ContainsKey("country_code")?Convert.ToString(result["country_code"]):"";
            if(country!="CN" && country!="TW" && country!="HK" && country!="MO") return false;
            lat=Convert.ToDouble(result["latitude"],System.Globalization.CultureInfo.InvariantCulture);
            lon=Convert.ToDouble(result["longitude"],System.Globalization.CultureInfo.InvariantCulture);
            return !Double.IsNaN(lat) && !Double.IsInfinity(lat) && !Double.IsNaN(lon) && !Double.IsInfinity(lon) && lat>=-90 && lat<=90 && lon>=-180 && lon<=180;
        } catch { return false; }
    }
    void FetchIpLocation(DateTime requestedAt) {
        var culture=System.Globalization.CultureInfo.InvariantCulture;
        var epoch=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc);
        ServicePointManager.SecurityProtocol|=(SecurityProtocolType)3072;
        foreach(string url in new string[]{"https://ipwho.is/?fields=success,country_code,latitude,longitude","https://ipapi.co/json/"}) {
            try {
                using(var client=new LocationClient()) {
                    client.Headers[HttpRequestHeader.UserAgent]="MossIsland/2.6";
                    double lat,lon;
                    if(!ParseIpLocation(client.DownloadString(url),out lat,out lon)) continue;
                    Send("location-ip|"+lat.ToString("R",culture)+"|"+lon.ToString("R",culture)+"|"+(DateTime.UtcNow-epoch).TotalSeconds.ToString("R",culture)+"|"+(requestedAt-epoch).TotalSeconds.ToString("R",culture));
                    return;
                }
            } catch { }
        }
        Send("location-failed|"+(requestedAt-epoch).TotalSeconds.ToString("R",culture));
    }
    void RequestIpLocation(double requestedEpoch) {
        if(Interlocked.CompareExchange(ref locating,1,0)!=0) return;
        ThreadPool.QueueUserWorkItem(delegate {
            try { FetchIpLocation(new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(requestedEpoch)); }
            finally { Interlocked.Exchange(ref locating,0); }
        });
    }
    void Send(string command) {
        if(renderer==null || renderer.HasExited || switching) return;
        if(command=="settings" || command=="collection" || command=="environment_test" || command=="map_editor" || command=="crop_editor") AllowSetForegroundWindow(renderer.Id);
        WriteAtomic(Path.Combine(ControlDir,"command"),DateTime.UtcNow.Ticks+"|"+command);
    }
    void ToggleLock() { if(mode!="immersive") return; locked=!locked; Send(locked?"lock":"unlock"); UpdateMenu(); }
    void UpdateMenu() {
        lockItem.Enabled=mode=="immersive"; lockItem.Text=locked?"解锁桌面":"锁定桌面";
        tray.Text="苔屿 · "+(locked?"沉浸壁纸 · 已锁定":"沉浸农场 · 操作中");
    }
    void ScheduleLaunch(int delay) {
        launchPending=true;
        nextLaunch=DateTime.UtcNow.AddMilliseconds(delay);
        launchDeadline=DateTime.UtcNow.AddSeconds(90);
    }
    long DesktopHost() {
        string bridge=Path.Combine(root,"DesktopBridge.exe");
        if(!File.Exists(bridge)) return 0;
        var info=new ProcessStartInfo(bridge,"--desktop-host");
        info.UseShellExecute=false; info.CreateNoWindow=true;
        info.WindowStyle=ProcessWindowStyle.Hidden; info.RedirectStandardOutput=true;
        using(var probe=Process.Start(info)) {
            if(!probe.WaitForExit(2500)) return 0;
            long handle;
            return Int64.TryParse(probe.StandardOutput.ReadToEnd().Trim(),out handle)?handle:0;
        }
    }
    void Launch() {
        if(renderer!=null && !renderer.HasExited) { launchPending=false; return; }
        long desktopHost=DesktopHost();
        if(desktopHost==0) {
            if(DateTime.UtcNow>=launchDeadline) {
                launchPending=false;
                tray.ShowBalloonTip(6000,"桌面尚未就绪","请在 Windows 桌面加载完成后重新双击程序。",ToolTipIcon.Warning);
            } else nextLaunch=DateTime.UtcNow.AddSeconds(2);
            return;
        }
        launchPending=false;
        // A previous host may have crashed. Give its renderer time to notice the
        // missing controller; never launch a second writer over an orphan.
        for(int attempt=0;attempt<30;attempt++) {
            bool found=false;
            foreach(string processName in new string[]{"MossCompanion","MossImmersive"})
                foreach(var existing in Process.GetProcessesByName(processName)) { if(!existing.HasExited) found=true; existing.Dispose(); }
            if(!found) break;
            if(attempt==29) { MessageBox.Show("已有渲染器仍在运行。请先退出该程序，再启动苔屿，以避免存档双写。","苔屿"); ExitHost(); return; }
            Thread.Sleep(150);
        }
        string exe=Path.Combine(root,"MossImmersive.exe");
        if(!File.Exists(exe)) { MessageBox.Show("缺少渲染程序："+exe,"苔屿"); ExitHost(); return; }
        File.Delete(Path.Combine(ControlDir,"command"));
        // Native OpenGL can attach to WorkerW without presenting on some Windows
        // sessions. Keep the desktop's known working Vulkan composition path.
        // Create the renderer as a desktop child from the beginning. Hiding the
        // initial Godot window can leave its presentation lifecycle uninitialized.
        // DesktopBridge then commits the exact icon-relative order and size.
        string graphics="--rendering-method mobile --rendering-driver vulkan --wid "+desktopHost;
        var info=new ProcessStartInfo(exe,graphics+" --log-file \""+Path.Combine(ControlDir,"renderer-"+mode+".log")+"\" -- --renderer="+mode+" --controller-pid="+Process.GetCurrentProcess().Id+" --control-dir=\""+ControlDir+"\"");
        info.UseShellExecute=false; info.CreateNoWindow=true; info.WorkingDirectory=root;
        renderer=Process.Start(info); locked=true; switching=false;
        File.WriteAllText(Path.Combine(data,"host-mode.txt"),mode);
        UpdateMenu();
    }
    void BeginStop() {
        launchPending=false;
        if(renderer==null || renderer.HasExited) { if(quitting) ExitHost(); return; }
        Send("quit"); switching=true; switchStarted=DateTime.UtcNow;
    }
    void Tick(object sender,EventArgs e) {
        string path=Path.Combine(ControlDir,"host_request");
        if(File.Exists(path)) {
            string request=File.ReadAllText(path);
            if(request!=lastRequest) {
                lastRequest=request;
                string action=request.Substring(request.IndexOf('|')+1);
                if(action=="immersive") { if(renderer==null || renderer.HasExited) ScheduleLaunch(0); }
                else if(action=="companion" || action=="overview" || action=="move" || action.StartsWith("size|") || action.StartsWith("position|")) { }
                else if(action=="locate") RequestLocation();
                else if(action=="locate-auto") RequestLocation(true);
                else if(action.StartsWith("locate-ip|")) { double stamp; if(Double.TryParse(action.Substring(10),System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out stamp)) RequestIpLocation(stamp); }
                else if(action=="exit") { quitting=true; BeginStop(); }
                else if(action=="lock") { locked=true; Send("lock"); UpdateMenu(); }
                else if(action=="unlock") { locked=false; Send("unlock"); UpdateMenu(); }
                else Send(action);
            }
        }
        if(renderer!=null && renderer.HasExited) {
            File.AppendAllText(Path.Combine(ControlDir,"startup.log"),DateTime.Now.ToString("s")+" Renderer exit="+renderer.ExitCode+Environment.NewLine);
            renderer.Dispose(); renderer=null;
            if(quitting) { ExitHost(); return; }
            tray.ShowBalloonTip(4000,"苔屿","壁纸已退出，请重新打开程序。存档保留在本地。",ToolTipIcon.Info);
        }
        if(launchPending && !quitting && DateTime.UtcNow>=nextLaunch) Launch();
        if(switching && renderer!=null && !renderer.HasExited && (DateTime.UtcNow-switchStarted).TotalSeconds>15) {
            switching=false; quitting=false;
            tray.ShowBalloonTip(6000,"切换尚未完成","当前渲染器尚未确认保存，已取消切换，避免存档双写。",ToolTipIcon.Warning);
        }
    }
    void ExitHost() { if(timer!=null) timer.Stop(); tray.Visible=false; tray.Dispose(); ExitThread(); }
    protected override void Dispose(bool disposing) { if(disposing && tray!=null) tray.Dispose(); base.Dispose(disposing); }
}
