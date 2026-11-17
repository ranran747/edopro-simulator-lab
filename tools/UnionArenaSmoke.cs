// Runs UNION ARENA AI-vs-AI games on the real 32-bit ocgcore, without the GUI (adapted from the Palworld
// project's tools/PalworldSmoke.cs).
//   UnionArenaSmoke.exe <project root> [seeds N|A-B] [core directory] [base runtime] [puzzle]
//   UnionArenaSmoke.exe <project root> 1 [core directory] [base runtime] fixtures|UnionArena_Fixture_<name>.lua [case]
//   UnionArenaSmoke.exe <project root> [seeds] [core directory] [base runtime] human [decks A-B]
// Human mode plays UnionArena_Player_Match.lua (player 0 = the human seat of unionarena_human.lua) and answers every
// dialog of player 0 at random (card selections, yes/no, options, numbers): each official deck A..B (default 1-83)
// once per seed against another deck, plus one game per seed with the deck and first-player dialogs too. It fails
// when the AI's seat asks for a decision, a prompt has no text (Debug.ShowHint "\x1bUA" slot), or the core rejects
// an answer. Logs: artifacts/human/.
// Fixture mode runs every case of pack/tests/UnionArena_Fixture_*.lua as its own duel (UnionArenaFixtureCase=<n>);
// a case passes when it logs UA|FIXTURE_PASS and no Lua or engine error occurred. Logs: artifacts/fixtures/.
// core directory: folder with ocgcore.dll ("" or "-" = default: this project's runtime/ProjectIgnis, whose core is the
//   Pokemon build with the Extra Deck mode used for resources; else the Pokemon runtime). base runtime: folder with
//   script/constant.lua and utility.lua (same default). Both are only read.
// Scripts come from pack/script, pack/puzzles and pack/tests directly; card scripts without behaviour get a stub.
// Writes artifacts/dm-<puzzle>-seed-<n>.log; a failed duel also writes artifacts/failures/<name>.trace.
// Exit code: 0 all games finished, 2 an engine or script error.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

class UnionArenaSmoke {
  [StructLayout(LayoutKind.Sequential)] struct CardData {
    public uint code, alias; public IntPtr setcodes; public uint type, level, attribute;
    public ulong race; public int attack, defense; public uint lscale, rscale, link;
  }
  [StructLayout(LayoutKind.Sequential)] struct Player { public uint lp, initialDraw, draw; }
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Reader(IntPtr payload, uint code, ref CardData data);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Script(IntPtr payload, IntPtr duel, IntPtr name);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Logger(IntPtr payload, IntPtr message, int type);
  [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Done(IntPtr payload, IntPtr data);
  [StructLayout(LayoutKind.Sequential)] struct Options {
    public ulong seed0, seed1, seed2, seed3, flags;
    public Player p1, p2;
    public Reader reader; public IntPtr payload1;
    public Script script; public IntPtr payload2;
    public Logger logger; public IntPtr payload3;
    public Done done; public IntPtr payload4;
    public byte unsafeLibraries;
  }
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool SetDllDirectory(string directory);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern void OCG_GetVersion(out int major, out int minor);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern int OCG_CreateDuel(out IntPtr duel, ref Options options);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern void OCG_DestroyDuel(IntPtr duel);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern void OCG_StartDuel(IntPtr duel);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern int OCG_DuelProcess(IntPtr duel);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr OCG_DuelGetMessage(IntPtr duel, out uint length);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern int OCG_LoadScript(IntPtr duel, byte[] buffer, uint size, string name);
  [DllImport("ocgcore.dll", CallingConvention=CallingConvention.Cdecl)] static extern void OCG_DuelSetResponse(IntPtr duel, byte[] bytes, uint length);

  static string root, baseRuntime;
  static Dictionary<uint, CardData> cards = new Dictionary<uint, CardData>();
  static List<string> trace = new List<string>();
  static List<string> errors = new List<string>();
  static byte[] forcedResponse;
  // human mode
  static bool autoHuman;
  static Random rng;
  static Dictionary<int,string> texts = new Dictionary<int,string>();
  static Dictionary<string,int> prompts = new Dictionary<string,int>();
  static List<string> humanErrors = new List<string>();
  const ulong TextCode = 0x0FFFFFF;
  static void CheckDesc(ulong desc, string where) {
    if((desc>>20)==TextCode && !texts.ContainsKey((int)(desc&0xFFFFF))) humanErrors.Add(where+": no text in slot "+(desc&0xFFFFF));
  }
  static void Count(string k) { int n; prompts.TryGetValue(k,out n); prompts[k]=n+1; }
  static byte[] Answer(params int[] values) {
    var b=new byte[values.Length*4];
    for(int i=0;i<values.Length;i++) BitConverter.GetBytes(values[i]).CopyTo(b,i*4);
    return b;
  }
  // a random answer to player 0's dialog at bytes[p] (the message byte); null when it is not one
  static byte[] AutoAnswer(byte[] bytes, int p) {
    int msg=bytes[p];
    if(msg!=12 && msg!=13 && msg!=14 && msg!=15 && msg!=143) return null;
    if(bytes[p+1]!=0) { humanErrors.Add("the AI seat was asked, native message="+msg); return null; }
    if(msg==12) { Count("effectYesNo"); CheckDesc(BitConverter.ToUInt64(bytes,p+16),"effect yes/no"); return Answer(rng.Next(2)); }
    if(msg==13) { Count("yesNo"); CheckDesc(BitConverter.ToUInt64(bytes,p+2),"yes/no"); return Answer(rng.Next(2)); }
    if(msg==14 || msg==143) {
      int count=bytes[p+2];
      if(msg==14) for(int i=0;i<count;i++) CheckDesc(BitConverter.ToUInt64(bytes,p+3+8*i),"option "+i);
      Count(msg==14?"option":"number");
      return Answer(rng.Next(count));
    }
    bool cancelable=bytes[p+2]!=0;
    int min=(int)BitConverter.ToUInt32(bytes,p+3), max=(int)BitConverter.ToUInt32(bytes,p+7), total=(int)BitConverter.ToUInt32(bytes,p+11);
    Count("cards");
    if(cancelable && rng.Next(5)==0) return Answer(-1);
    int k=rng.Next(min,max+1);
    var idx=new List<int>();
    for(int i=0;i<total;i++) idx.Add(i);
    for(int i=idx.Count-1;i>0;i--) { int j=rng.Next(i+1); int t=idx[i]; idx[i]=idx[j]; idx[j]=t; }
    var values=new List<int> {0,k};
    for(int i=0;i<k;i++) values.Add(idx[i]);
    return Answer(values.ToArray());
  }
  static Reader reader = ReadCard;
  static Script script = ReadScript;
  static Logger logger = Log;
  static Done done = ReaderDone;
  static readonly byte[] stub = Encoding.ASCII.GetBytes("local s,id=GetID()\nfunction s.initial_effect(c) end\n");

  static ulong SeedStream(int seed, int stream) {
    unchecked {
      ulong value=(ulong)seed+0x9E3779B97F4A7C15UL*(ulong)(stream+1);
      value=(value^(value>>30))*0xBF58476D1CE4E5B9UL;
      value=(value^(value>>27))*0x94D049BB133111EBUL;
      return value^(value>>31);
    }
  }
  static string Utf8(IntPtr pointer) {
    var bytes = new List<byte>();
    for(int i=0; Marshal.ReadByte(pointer,i)!=0; i++) bytes.Add(Marshal.ReadByte(pointer,i));
    return Encoding.UTF8.GetString(bytes.ToArray());
  }
  static void ReadCard(IntPtr payload, uint code, ref CardData data) {
    CardData found;
    if(cards.TryGetValue(code,out found)) data=found;
  }
  static int Load(IntPtr duel, string name) {
    foreach(string folder in new [] {Path.Combine(root,"pack","script"), Path.Combine(root,"pack","puzzles"),
        Path.Combine(root,"pack","tests"), Path.Combine(root,"sandbox"), baseRuntime}) {
      string path=Path.Combine(folder,name);
      if(File.Exists(path)) {
        byte[] buffer=File.ReadAllBytes(path);
        return OCG_LoadScript(duel,buffer,(uint)buffer.Length,name);
      }
    }
    var m=Regex.Match(name,@"^c(\d+)\.lua$");
    if(m.Success && cards.ContainsKey(uint.Parse(m.Groups[1].Value))) return OCG_LoadScript(duel,stub,(uint)stub.Length,name);
    return 0;
  }
  static int ReadScript(IntPtr payload, IntPtr duel, IntPtr name) { return Load(duel,Utf8(name)); }
  static void Log(IntPtr payload, IntPtr pointer, int type) {
    string message=Utf8(pointer);
    if(type==0) errors.Add(message);
    if(message.StartsWith("UA|")) trace.Add(message);
  }
  static void ReaderDone(IntPtr payload, IntPtr data) { }
  static int Messages(IntPtr duel, ref int winner) {
    uint size; IntPtr data=OCG_DuelGetMessage(duel,out size);
    byte[] bytes=new byte[size]; Marshal.Copy(data,bytes,0,(int)size);
    int offset=0,last=-1;
    while(offset<bytes.Length) {
      int length=BitConverter.ToInt32(bytes,offset); offset+=4;
      if(length<1 || offset+length>bytes.Length) throw new Exception("Invalid native message length");
      last=bytes[offset];
      if(last==164 && length>=3) {
        int n=BitConverter.ToUInt16(bytes,offset+1);
        string s=Encoding.UTF8.GetString(bytes,offset+3,Math.Min(n,length-3));
        int sep=s.IndexOf('\x1f');
        int slot;
        if(s.StartsWith("\x1bUA") && sep>3 && int.TryParse(s.Substring(3,sep-3),out slot)) texts[slot]=s.Substring(sep+1);
      }
      if(last==2 && bytes[offset+1]==3) CheckDesc(BitConverter.ToUInt64(bytes,offset+3),"select hint");
      if(last==1 && autoHuman) humanErrors.Add("the core rejected an answer (MSG_RETRY)");
      if(autoHuman) { byte[] a=AutoAnswer(bytes,offset); if(a!=null) forcedResponse=a; }
      if(last==18) {
        // MSG_SELECT_PLACE: only answered when the scripts left exactly one free slot (EDOPro auto placement)
        byte selecting=bytes[offset+1];
        uint enabled=~BitConverter.ToUInt32(bytes,offset+3);
        int bit=0; while(bit<32 && (enabled&(1u<<bit))==0) bit++;
        byte player=bit<16?selecting:(byte)(1-selecting);
        int local=bit%16;
        forcedResponse=new byte[] {player,(byte)(local<8?4:8),(byte)(local%8)};
      }
      if(last==5) winner=bytes[offset+1];
      offset+=length;
    }
    return last;
  }
  static int Run(int seed, string puzzle) {
    string logPath=Path.Combine(root,"artifacts","ua-"+Path.GetFileNameWithoutExtension(puzzle)+"-seed-"+seed+".log");
    string error=Duel(seed,puzzle,"",logPath);
    string name=Path.GetFileNameWithoutExtension(puzzle)+"-seed-"+seed;
    if(error!=null) {
      DumpTrace(name,error);
      Console.WriteLine("ERROR seed="+seed+": "+error);
      return 2;
    }
    string win=trace.FindLast(s=>s.StartsWith("UA|WIN|"));
    bool allCards = new [] {0, 1}.All(seat => trace.Exists(line =>
      line.StartsWith("UA|CARDS|player=" + seat + ";") && line.EndsWith(";total=53")));
    if(win==null || win.Contains("reason=deck_rejected;") || !allCards) {
      DumpTrace(name,"expected a match result and 53 cards per seat");
      Console.WriteLine("ERROR seed="+seed+": expected a match result and 53 cards per seat");
      return 2;
    }
    Console.WriteLine("DONE seed="+seed+" "+win.Substring(7)+" lines="+trace.Count+" log="+logPath);
    return 0;
  }
  // One human-mode duel; preset = Lua table text for UnionArenaPlayPreset ("" = choose in the dialogs too).
  static int RunHuman(int seed, string name, string preset) {
    string folder=Path.Combine(root,"artifacts","human");
    Directory.CreateDirectory(folder);
    string logPath=Path.Combine(folder,name+".log");
    autoHuman=true; rng=new Random(seed*7919+name.GetHashCode());
    texts.Clear(); prompts.Clear(); humanErrors.Clear();
    string config="\nUnionArenaPlayerSaveFile=[["+Path.Combine(folder,"last-"+name+".txt").Replace("\\","/")+"]]";
    if(preset!="") config+="\nUnionArenaPlayPreset="+preset;
    string error=Duel(seed,"UnionArena_Player_Match.lua",config,logPath);
    autoHuman=false;
    if(error==null && humanErrors.Count>0) error=string.Join("; ",humanErrors.ToArray());
    string win=trace.FindLast(s=>s.StartsWith("UA|WIN|"));
    if(error==null && win==null) error="the game did not finish";
    var keys=new List<string>(prompts.Keys); keys.Sort(StringComparer.Ordinal);
    var parts=new List<string>(); foreach(string k in keys) parts.Add(k+"="+prompts[k]);
    if(error!=null) {
      DumpTrace("human-"+name,error);
      Console.WriteLine("ERROR "+name+": "+error);
      return 2;
    }
    string decks=trace.Find(s=>s.StartsWith("UA|DECKS|"));
    Console.WriteLine("DONE "+name+" "+win.Substring(7)+" prompts: "+string.Join(" ",parts.ToArray())+(decks!=null?" "+decks.Substring(9):""));
    return 0;
  }
  static int RunHumanSweep(int firstSeed, int lastSeed, int fromDeck, int toDeck) {
    int bad=0, games=0;
    for(int seed=firstSeed;seed<=lastSeed;seed++) {
      for(int d=fromDeck;d<=toDeck;d++) {
        int opp=((d-1+17*seed)%83)+1;
        if(opp==d) opp=d%83+1;
        string first=((d+seed)%3)==0?"0":(((d+seed)%3)==1?"1":"nil");
        string name="D"+d.ToString("D2")+"-vs-D"+opp.ToString("D2")+"-seed-"+seed;
        games++;
        if(RunHuman(seed,name,"{me='D"+d.ToString("D2")+"',opp='D"+opp.ToString("D2")+"',first="+first+"}")!=0) bad++;
      }
      games++;
      if(RunHuman(seed,"dialogs-seed-"+seed,"")!=0) bad++;
      // decks from the deck editor (artifacts/deck, tools/make_test_ydk.py): both seats, and against an official deck
      games+=2;
      if(RunHuman(seed,"ydk-D22-vs-ydk-D69-seed-"+seed,"{me='ydk:ua-test-D22',opp='ydk:ua-test-D69',first=nil}")!=0) bad++;
      if(RunHuman(seed,"ydk-D69-vs-D10-seed-"+seed,"{me='ydk:ua-test-D69',opp='D10',first=1}")!=0) bad++;
    }
    Console.WriteLine("human: games="+games+" seeds="+firstSeed+"-"+lastSeed+" failed="+bad);
    return bad>0?2:0;
  }
  // Prints the last 40 trace lines and keeps the whole trace of the failed duel (as the Pokemon harness does):
  // artifacts/failures/<name>.trace = every PAL| line, then the engine/Lua errors and the failure message.
  static void DumpTrace(string name, string message) {
    int from=Math.Max(0,trace.Count-40);
    for(int i=from;i<trace.Count;i++) Console.WriteLine("  "+trace[i]);
    string folder=Path.Combine(root,"artifacts","failures");
    Directory.CreateDirectory(folder);
    var lines=new List<string>(trace);
    foreach(string e in errors) lines.Add("ERROR|"+e);
    lines.Add("FAILURE|"+message);
    string path=Path.Combine(folder,name+".trace");
    File.WriteAllLines(path,lines.ToArray(),new UTF8Encoding(false));
    Console.WriteLine("  trace: "+path);
  }
  // One duel per fixture case. Returns the number of failed cases.
  static int RunFixtures(string file, int onlyCase) {
    int count=-1, failed=0;
    string folder=Path.Combine(root,"artifacts","fixtures");
    Directory.CreateDirectory(folder);
    for(int n=onlyCase>0?onlyCase:1; count<0 || n<=(onlyCase>0?onlyCase:count); n++) {
      string logPath=Path.Combine(folder,Path.GetFileNameWithoutExtension(file)+"-"+n.ToString("D3")+".log");
      string error=Duel(1,file,"\nUnionArenaFixtureCase="+n,logPath);
      string countLine=trace.Find(s=>s.StartsWith("UA|FIXTURE_COUNT|n="));
      if(countLine!=null) count=int.Parse(countLine.Substring(19));
      else if(count<0) { DumpTrace(Path.GetFileNameWithoutExtension(file)+"-load",error??"no count"); Console.WriteLine("FAIL "+file+": no UA|FIXTURE_COUNT ("+error+")"); return 1; }
      string nameLine=trace.Find(s=>s.StartsWith("UA|FIXTURE|case="));
      string name=nameLine!=null?nameLine.Substring(16):"?";
      bool passed=error==null && trace.Exists(s=>s.StartsWith("UA|FIXTURE_PASS|"));
      if(!passed) {
        failed++;
        DumpTrace(Path.GetFileNameWithoutExtension(file)+"-"+n.ToString("D3"),error??"no UA|FIXTURE_PASS");
        Console.WriteLine("FAIL "+Path.GetFileNameWithoutExtension(file)+" #"+n+" "+name+": "+(error??"no UA|FIXTURE_PASS"));
      } else {
        int checks=trace.FindAll(s=>s.StartsWith("UA|CHECK|")).Count;
        Console.WriteLine("PASS "+Path.GetFileNameWithoutExtension(file)+" #"+n+" "+name+" checks="+checks);
      }
      if(onlyCase>0) break;
    }
    return failed;
  }
  // Plays one duel; returns null when no Lua or engine error occurred, otherwise the error text.
  static string Duel(int seed, string puzzle, string extraConfig, string logPath) {
    trace.Clear(); errors.Clear(); forcedResponse=null;
    var options=new Options {
      seed0=SeedStream(seed,0),seed1=SeedStream(seed,1),seed2=SeedStream(seed,2),seed3=SeedStream(seed,3),
      p1=new Player {lp=10},p2=new Player {lp=10},
      reader=reader,script=script,logger=logger,done=done,unsafeLibraries=1
    };
    IntPtr duel;
    if(OCG_CreateDuel(out duel,ref options)!=0) throw new Exception("Native create failed");
    int winner=-1;
    try {
      byte[] logSetting=Encoding.UTF8.GetBytes("UnionArenaAIDemoLogFile=[["+logPath.Replace("\\","/")+"]]"+extraConfig);
      if(Load(duel,"constant.lua")==0 || Load(duel,"utility.lua")==0 ||
         OCG_LoadScript(duel,logSetting,(uint)logSetting.Length,"unionarena-config")==0)
        throw new Exception("Lua initialization failed: "+string.Join(";",errors.ToArray()));
      if(Load(duel,puzzle)==0) throw new Exception("Puzzle failed to load: "+string.Join(";",errors.ToArray()));
      if(errors.Count>0) throw new Exception(string.Join(";",errors.ToArray()));
      Messages(duel,ref winner);
      OCG_StartDuel(duel);
      for(int step=0;step<200000;step++) {
        int status=OCG_DuelProcess(duel);
        int message=Messages(duel,ref winner);
        if(errors.Count>0) throw new Exception(string.Join(";",errors.ToArray()));
        if(winner>=0 || status==0) break;
        if(status==1) {
          if(forcedResponse==null) throw new Exception("Unexpected human decision, native message="+message);
          OCG_DuelSetResponse(duel,forcedResponse,(uint)forcedResponse.Length);
          forcedResponse=null;
        }
      }
    } catch(Exception e) {
      return e.Message;
    } finally {
      OCG_DestroyDuel(duel);
    }
    return null;
  }
  static int Main(string[] args) {
    try {
      Console.OutputEncoding=new UTF8Encoding(false);
      if(args.Length<1) { Console.WriteLine("usage: UnionArenaSmoke.exe <project root> [seeds N|A-B] [core directory] [base runtime] [puzzle|fixtures] [case]"); return 2; }
      root=Path.GetFullPath(args[0]);
      // seeds: "N" plays seeds 1..N, "A-B" plays seeds A..B (tools/run_parallel.ps1 splits seeds this way).
      int firstSeed=1, lastSeed=1;
      if(args.Length>1) {
        string[] range=args[1].Split('-');
        if(range.Length==2) { firstSeed=int.Parse(range[0]); lastSeed=int.Parse(range[1]); }
        else lastSeed=int.Parse(args[1]);
      }
      string ownRuntime=Path.Combine(root,"runtime","ProjectIgnis");
      string defaultRuntime=ownRuntime;
      string core=args.Length>2&&args[2]!=""&&args[2]!="-"?Path.GetFullPath(args[2]):defaultRuntime;
      baseRuntime=args.Length>3&&args[3]!=""&&args[3]!="-"?Path.GetFullPath(args[3]):Path.Combine(defaultRuntime,"script");
      string puzzle=args.Length>4?args[4]:"UnionArena_AI_vs_AI.lua";
      SetDllDirectory(core);
      Directory.CreateDirectory(Path.Combine(root,"artifacts"));
      Directory.SetCurrentDirectory(Path.Combine(root,"artifacts"));
      foreach(string row in File.ReadAllLines(Path.Combine(root,"pack","cards.tsv"))) {
        if(row.Trim()=="") continue;
        string[] f=row.Split('\t'); uint code=uint.Parse(f[0]);
        cards[code]=new CardData {code=code,type=uint.Parse(f[1]),attack=int.Parse(f[2]),defense=int.Parse(f[3]),
          alias=uint.Parse(f[4]),level=uint.Parse(f[5]),attribute=uint.Parse(f[6]),race=ulong.Parse(f[7])};
      }
      int major,minor; OCG_GetVersion(out major,out minor);
      if(major!=11) throw new Exception("Unrecognized native API: "+major+"."+minor);
      if(puzzle=="fixtures" || puzzle.StartsWith("UnionArena_Fixture_")) {
        int onlyCase=args.Length>5?int.Parse(args[5]):0;
        var files=new List<string>();
        if(puzzle=="fixtures") {
          foreach(string f in Directory.GetFiles(Path.Combine(root,"pack","tests"),"UnionArena_Fixture_*.lua")) files.Add(Path.GetFileName(f));
          files.Sort(StringComparer.Ordinal);
        } else files.Add(puzzle);
        int failed=0;
        foreach(string f in files) failed+=RunFixtures(f,onlyCase);
        Console.WriteLine("fixtures: files="+files.Count+" failed="+failed);
        return failed>0?2:0;
      }
      if(puzzle=="human") {
        int fromDeck=1, toDeck=83;
        if(args.Length>5) { string[] r=args[5].Split('-'); fromDeck=int.Parse(r[0]); toDeck=int.Parse(r[r.Length-1]); }
        return RunHumanSweep(firstSeed,lastSeed,fromDeck,toDeck);
      }
      int worst=0, bad=0;
      for(int seed=firstSeed;seed<=lastSeed;seed++) {
        int result=Run(seed,puzzle);
        if(result!=0) bad++;
        worst=Math.Max(worst,result);
      }
      Console.WriteLine("games: puzzle="+puzzle+" seeds="+firstSeed+"-"+lastSeed+" failed="+bad);
      return worst;
    } catch(Exception e) {
      Console.Error.WriteLine(e);
      return 2;
    }
  }
}
