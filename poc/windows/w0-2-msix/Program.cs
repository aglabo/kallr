// PoC-W0-2: same operations as W0-1, run from an MSIX-packaged process.
// Difference from W0-1: without --aumid the notifier uses the package's own AUMID
// (CreateToastNotifier()), because a packaged app has an AUMID from its manifest.
// Usage:
//   identity
//   add  --at <datetime> --title <text> [--aumid <id>] [--batch B] [--alarm A]
//   show [--aumid <id>]
//   list [--aumid <id>]
//   cancel --batch B --alarm A [--aumid <id>]
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

if (args.Length == 0) { Console.Error.WriteLine("usage: identity|add|show|list|cancel ..."); return 1; }

string? Opt(string name)
{
  var i = Array.IndexOf(args, "--" + name);
  return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
}

var aumid = Opt("aumid");
var batch = Opt("batch") ?? "B";
var alarm = Opt("alarm") ?? "A";

try
{
  if (args[0] == "identity")
  {
    var p = Windows.ApplicationModel.Package.Current;
    Console.WriteLine($"packaged: family={p.Id.FamilyName} full={p.Id.FullName}");
    return 0;
  }

  var notifier = aumid is null
      ? ToastNotificationManager.CreateToastNotifier()
      : ToastNotificationManager.CreateToastNotifier(aumid);
  var who = aumid ?? "(package AUMID)";

  switch (args[0])
  {
    case "add":
      {
        // No offset in the input (e.g. "2026-11-16 23:30") is read as Japan Standard Time.
        var jst = TimeZoneInfo.FindSystemTimeZoneById("Tokyo Standard Time");
        var raw = Opt("at") ?? throw new ArgumentException("--at required");
        var hasOffset = System.Text.RegularExpressions.Regex.IsMatch(raw, @"(Z|[+-]\d{2}:?\d{2})$");
        var local = hasOffset ? default : DateTime.Parse(raw);
        var at = hasOffset ? DateTimeOffset.Parse(raw) : new DateTimeOffset(local, jst.GetUtcOffset(local));
        Console.WriteLine($"now(JST)={TimeZoneInfo.ConvertTime(DateTimeOffset.Now, jst):yyyy-MM-dd HH:mm:ss zzz}");
        var title = Opt("title") ?? "PoC W0-2";
        var xml = new XmlDocument();
        xml.LoadXml($"<toast><visual><binding template=\"ToastGeneric\"><text>{System.Security.SecurityElement.Escape(title)}</text></binding></visual></toast>");
        var toast = new ScheduledToastNotification(xml, at) { Tag = alarm, Group = batch };
        notifier.AddToSchedule(toast);
        Console.WriteLine($"scheduled: aumid={who} group={batch} tag={alarm} at={at:yyyy-MM-ddTHH:mm:sszzz}");
        return 0;
      }
    case "show":
      {
        var xml = new XmlDocument();
        xml.LoadXml("<toast><visual><binding template=\"ToastGeneric\"><text>PoC W0-2 immediate</text></binding></visual></toast>");
        notifier.Show(new ToastNotification(xml));
        Console.WriteLine($"shown: aumid={who} setting={notifier.Setting}");
        return 0;
      }
    case "list":
      foreach (var t in notifier.GetScheduledToastNotifications())
        Console.WriteLine($"aumid={who} group={t.Group} tag={t.Tag} at={t.DeliveryTime:yyyy-MM-ddTHH:mm:sszzz}");
      return 0;
    case "cancel":
      foreach (var t in notifier.GetScheduledToastNotifications())
        if (t.Group == batch && t.Tag == alarm) { notifier.RemoveFromSchedule(t); Console.WriteLine("removed"); }
      return 0;
    default:
      Console.Error.WriteLine("unknown command"); return 1;
  }
}
catch (Exception e)
{
  Console.Error.WriteLine($"{e.GetType().FullName}: 0x{e.HResult:X8} {e.Message}");
  return 2;
}
