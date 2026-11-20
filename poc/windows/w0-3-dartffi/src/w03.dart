// PoC-W0-3 (run: dart run src/w03.dart <command>): the W0-1 operations (add / list / cancel / show / register-reg) from Dart FFI.
// No WinRT binding package is used: the WinRT COM vtables are called by hand through dart:ffi.
// Usage:
//   add  --at <datetime> --title <text> [--aumid <id>] [--batch B] [--alarm A]
//   show [--aumid <id>]
//   list [--aumid <id>]
//   cancel --batch B --alarm A [--aumid <id>]
//   register-reg | unregister-reg [--aumid <id>]
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const defaultAumid = 'Kallr.Poc.W01';

// ---- combase.dll ----------------------------------------------------------
final _combase = DynamicLibrary.open('combase.dll');

final _roInitialize = _combase
    .lookupFunction<Int32 Function(Int32), int Function(int)>('RoInitialize');
final _roGetActivationFactory = _combase.lookupFunction<
    Int32 Function(IntPtr, Pointer<Guid>, Pointer<Pointer>),
    int Function(
        int, Pointer<Guid>, Pointer<Pointer>)>('RoGetActivationFactory');
final _roActivateInstance = _combase.lookupFunction<
    Int32 Function(IntPtr, Pointer<Pointer>),
    int Function(int, Pointer<Pointer>)>('RoActivateInstance');
final _windowsCreateString = _combase.lookupFunction<
    Int32 Function(Pointer<Utf16>, Uint32, Pointer<IntPtr>),
    int Function(Pointer<Utf16>, int, Pointer<IntPtr>)>('WindowsCreateString');
final _windowsDeleteString =
    _combase.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'WindowsDeleteString');
final _windowsGetStringRawBuffer = _combase.lookupFunction<
    Pointer<Utf16> Function(IntPtr, Pointer<Uint32>),
    Pointer<Utf16> Function(int, Pointer<Uint32>)>('WindowsGetStringRawBuffer');

final class Guid extends Struct {
  @Uint32()
  external int d1;
  @Uint16()
  external int d2;
  @Uint16()
  external int d3;
  @Array(8)
  external Array<Uint8> d4;
}

class HResultException implements Exception {
  HResultException(this.hr, this.where);
  final int hr;
  final String where;
  @override
  String toString() =>
      'HResultException: 0x${(hr & 0xFFFFFFFF).toRadixString(16).toUpperCase().padLeft(8, '0')} at $where';
}

void check(int hr, String where) {
  if (hr < 0) throw HResultException(hr, where);
}

Pointer<Guid> guid(String s) {
  final h = s.replaceAll(RegExp(r'[{}-]'), '');
  final g = calloc<Guid>();
  g.ref.d1 = int.parse(h.substring(0, 8), radix: 16);
  g.ref.d2 = int.parse(h.substring(8, 12), radix: 16);
  g.ref.d3 = int.parse(h.substring(12, 16), radix: 16);
  for (var i = 0; i < 8; i++) {
    g.ref.d4[i] = int.parse(h.substring(16 + i * 2, 18 + i * 2), radix: 16);
  }
  return g;
}

int hstr(String s) {
  final p = s.toNativeUtf16();
  final out = calloc<IntPtr>();
  check(_windowsCreateString(p, s.length, out), 'WindowsCreateString');
  final h = out.value;
  calloc.free(p);
  calloc.free(out);
  return h;
}

String readHstr(int h) {
  if (h == 0) return '';
  final len = calloc<Uint32>();
  final s = _windowsGetStringRawBuffer(h, len).toDartString(length: len.value);
  calloc.free(len);
  return s;
}

// ---- COM vtable calls ------------------------------------------------------
Pointer<NativeFunction<T>> _slot<T extends Function>(Pointer obj, int index) {
  final vtbl = obj.cast<Pointer<Pointer>>().value;
  return vtbl[index].cast<NativeFunction<T>>();
}

int release(Pointer obj) => _slot<Uint32 Function(Pointer)>(obj, 2)
    .asFunction<int Function(Pointer)>()(obj);

Pointer queryInterface(Pointer obj, String iid) {
  final g = guid(iid);
  final out = calloc<Pointer>();
  final hr = _slot<Int32 Function(Pointer, Pointer<Guid>, Pointer<Pointer>)>(
              obj, 0)
          .asFunction<int Function(Pointer, Pointer<Guid>, Pointer<Pointer>)>()(
      obj, g, out);
  check(hr, 'QueryInterface $iid');
  final r = out.value;
  calloc.free(g);
  calloc.free(out);
  return r;
}

/// obj->method(out Pointer)
Pointer callOut(Pointer obj, int index, String where) {
  final out = calloc<Pointer>();
  check(
      _slot<Int32 Function(Pointer, Pointer<Pointer>)>(obj, index)
          .asFunction<int Function(Pointer, Pointer<Pointer>)>()(obj, out),
      where);
  final r = out.value;
  calloc.free(out);
  return r;
}

/// obj->method(Pointer arg)
void callPtr(Pointer obj, int index, Pointer arg, String where) => check(
    _slot<Int32 Function(Pointer, Pointer)>(obj, index)
        .asFunction<int Function(Pointer, Pointer)>()(obj, arg),
    where);

/// obj->method(HSTRING)
void callHstr(Pointer obj, int index, String value, String where) {
  final h = hstr(value);
  check(
      _slot<Int32 Function(Pointer, IntPtr)>(obj, index)
          .asFunction<int Function(Pointer, int)>()(obj, h),
      where);
  _windowsDeleteString(h);
}

/// obj->method(out HSTRING) as Dart String
String getHstr(Pointer obj, int index, String where) {
  final out = calloc<IntPtr>();
  check(
      _slot<Int32 Function(Pointer, Pointer<IntPtr>)>(obj, index)
          .asFunction<int Function(Pointer, Pointer<IntPtr>)>()(obj, out),
      where);
  final s = readHstr(out.value);
  _windowsDeleteString(out.value);
  calloc.free(out);
  return s;
}

int getInt32(Pointer obj, int index, String where) {
  final out = calloc<Int32>();
  check(
      _slot<Int32 Function(Pointer, Pointer<Int32>)>(obj, index)
          .asFunction<int Function(Pointer, Pointer<Int32>)>()(obj, out),
      where);
  final v = out.value;
  calloc.free(out);
  return v;
}

int getInt64(Pointer obj, int index, String where) {
  final out = calloc<Int64>();
  check(
      _slot<Int32 Function(Pointer, Pointer<Int64>)>(obj, index)
          .asFunction<int Function(Pointer, Pointer<Int64>)>()(obj, out),
      where);
  final v = out.value;
  calloc.free(out);
  return v;
}

Pointer factory(String className, String iid) {
  final cn = hstr(className);
  final g = guid(iid);
  final out = calloc<Pointer>();
  check(
      _roGetActivationFactory(cn, g, out), 'RoGetActivationFactory $className');
  final r = out.value;
  _windowsDeleteString(cn);
  calloc.free(g);
  calloc.free(out);
  return r;
}

// ---- WinRT interfaces (vtable index = 6 + position in the interface) -------
// 7 CreateToastNotifierWithId
const iidToastManagerStatics = '{50ac103f-d235-4598-bbef-98fe4d1a3ad4}';
// 6 Show 8 get_Setting 9 AddToSchedule 10 RemoveFromSchedule 11 GetScheduledToastNotifications
const iidToastNotifier = '{75927b93-03f3-41ec-91d3-6e5bac1b38e7}';
// 6 CreateToastNotification(IXmlDocument)
const iidToastFactory = '{04124b20-82c6-4229-b109-fd9ed4662b53}';
// 6 CreateScheduledToastNotification(IXmlDocument, DateTime)
const iidScheduledFactory = '{e7bed191-0bb9-4189-8394-31761b476fd7}';
// 7 get_DeliveryTime
const iidScheduled = '{79f577f8-0de7-48cd-9740-9b370490c838}';
// 6 put_Tag 7 get_Tag 8 put_Group 9 get_Group
const iidScheduled2 = '{a66ea09c-31b4-43b0-b5dd-7a40e85363b1}';
// 6 LoadXml
const iidXmlDocumentIO = '{6cd0e74e-ee65-4489-9ebf-ca43e87ba637}';

Pointer createXml(String xml) {
  final cn = hstr('Windows.Data.Xml.Dom.XmlDocument');
  final doc = calloc<Pointer>();
  check(_roActivateInstance(cn, doc), 'RoActivateInstance XmlDocument');
  _windowsDeleteString(cn);
  final io = queryInterface(doc.value, iidXmlDocumentIO);
  callHstr(io, 6, xml, 'IXmlDocumentIO.LoadXml');
  release(io);
  return doc.value; // the object itself implements IXmlDocument
}

Pointer createNotifier(String aumid) {
  final statics = factory('Windows.UI.Notifications.ToastNotificationManager',
      iidToastManagerStatics);
  final h = hstr(aumid);
  final out = calloc<Pointer>();
  check(
      _slot<Int32 Function(Pointer, IntPtr, Pointer<Pointer>)>(statics, 7)
              .asFunction<int Function(Pointer, int, Pointer<Pointer>)>()(
          statics, h, out),
      'CreateToastNotifierWithId');
  final n = out.value;
  _windowsDeleteString(h);
  calloc.free(out);
  release(statics);
  return n;
}

// ---- time ------------------------------------------------------------------
const _ticksBetween1601And1970 = 116444736000000000; // 100 ns units
int toWinRtTicks(DateTime utc) =>
    utc.microsecondsSinceEpoch * 10 + _ticksBetween1601And1970;
DateTime fromWinRtTicks(int t) =>
    DateTime.fromMicrosecondsSinceEpoch((t - _ticksBetween1601And1970) ~/ 10,
        isUtc: true);

/// No offset in the input (e.g. "2026-11-16 23:30") is read as Japan Standard Time (as in W0-1).
DateTime parseAt(String raw) {
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  return DateTime.parse(hasOffset ? raw : '$raw+09:00').toUtc();
}

String fmtJst(DateTime utc) {
  final j = utc.add(const Duration(hours: 9));
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(j.year, 4)}-${p(j.month)}-${p(j.day)}T${p(j.hour)}:${p(j.minute)}:${p(j.second)}+09:00';
}

// ---- main ------------------------------------------------------------------
String? opt(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

typedef Scheduled = ({Pointer item, String group, String tag, DateTime at});

List<Scheduled> scheduled(Pointer notifier) {
  final vec = callOut(notifier, 11, 'GetScheduledToastNotifications');
  final sizeOut = calloc<Uint32>();
  check(
      _slot<Int32 Function(Pointer, Pointer<Uint32>)>(vec, 7)
          .asFunction<int Function(Pointer, Pointer<Uint32>)>()(vec, sizeOut),
      'IVectorView.get_Size');
  final size = sizeOut.value;
  calloc.free(sizeOut);
  final items = <Scheduled>[];
  for (var i = 0; i < size; i++) {
    final out = calloc<Pointer>();
    check(
        _slot<Int32 Function(Pointer, Uint32, Pointer<Pointer>)>(vec, 6)
                .asFunction<int Function(Pointer, int, Pointer<Pointer>)>()(
            vec, i, out),
        'IVectorView.GetAt');
    final item = out.value;
    calloc.free(out);
    final s1 = queryInterface(item, iidScheduled);
    final s2 = queryInterface(item, iidScheduled2);
    items.add((
      item: item,
      group: getHstr(s2, 9, 'get_Group'),
      tag: getHstr(s2, 7, 'get_Tag'),
      at: fromWinRtTicks(getInt64(s1, 7, 'get_DeliveryTime')),
    ));
    release(s1);
    release(s2);
  }
  release(vec);
  return items;
}

int run(List<String> args) {
  if (args.isEmpty) {
    stderr
        .writeln('usage: add|show|list|cancel|register-reg|unregister-reg ...');
    return 1;
  }
  final aumid = opt(args, 'aumid') ?? defaultAumid;
  final batch = opt(args, 'batch') ?? 'B';
  final alarm = opt(args, 'alarm') ?? 'A';
  final regKey = r'HKCU\Software\Classes\AppUserModelId\' + aumid;

  switch (args[0]) {
    case 'register-reg':
      final r = Process.runSync('reg',
          ['add', regKey, '/v', 'DisplayName', '/d', 'Kallr PoC W03', '/f']);
      stdout.write(r.stdout);
      return r.exitCode;
    case 'unregister-reg':
      final r = Process.runSync('reg', ['delete', regKey, '/f']);
      stdout.writeln(
          r.exitCode == 0 ? 'registry key removed' : 'registry key not found');
      return 0;
  }

  check(_roInitialize(1 /* RO_INIT_MULTITHREADED */), 'RoInitialize');
  final notifier = createNotifier(aumid);
  switch (args[0]) {
    case 'add':
      final raw = opt(args, 'at') ?? (throw ArgumentError('--at required'));
      final at = parseAt(raw);
      stdout.writeln('now(JST)=${fmtJst(DateTime.now().toUtc())}');
      final title = opt(args, 'title') ?? 'PoC W0-3';
      final xml = createXml(
          '<toast><visual><binding template="ToastGeneric"><text>${esc(title)}</text></binding></visual></toast>');
      final f = factory('Windows.UI.Notifications.ScheduledToastNotification',
          iidScheduledFactory);
      final out = calloc<Pointer>();
      check(
          _slot<Int32 Function(Pointer, Pointer, Int64, Pointer<Pointer>)>(f, 6)
                  .asFunction<
                      int Function(Pointer, Pointer, int, Pointer<Pointer>)>()(
              f, xml, toWinRtTicks(at), out),
          'CreateScheduledToastNotification');
      final toast = out.value;
      calloc.free(out);
      final t2 = queryInterface(toast, iidScheduled2);
      callHstr(t2, 6, alarm, 'put_Tag');
      callHstr(t2, 8, batch, 'put_Group');
      callPtr(notifier, 9, toast, 'AddToSchedule');
      stdout.writeln(
          'scheduled: aumid=$aumid group=$batch tag=$alarm at=${fmtJst(at)}');
      return 0;
    case 'show':
      final xml = createXml(
          '<toast><visual><binding template="ToastGeneric"><text>PoC W0-3 immediate</text></binding></visual></toast>');
      final f = factory(
          'Windows.UI.Notifications.ToastNotification', iidToastFactory);
      final out = calloc<Pointer>();
      check(
          _slot<Int32 Function(Pointer, Pointer, Pointer<Pointer>)>(f, 6)
              .asFunction<
                  int Function(
                      Pointer, Pointer, Pointer<Pointer>)>()(f, xml, out),
          'CreateToastNotification');
      callPtr(notifier, 6, out.value, 'Show');
      stdout.writeln(
          'shown: aumid=$aumid setting=${getInt32(notifier, 8, 'get_Setting')}');
      return 0;
    case 'list':
      for (final t in scheduled(notifier)) {
        stdout.writeln(
            'aumid=$aumid group=${t.group} tag=${t.tag} at=${fmtJst(t.at)}');
      }
      return 0;
    case 'cancel':
      for (final t in scheduled(notifier)) {
        if (t.group == batch && t.tag == alarm) {
          callPtr(notifier, 10, t.item, 'RemoveFromSchedule');
          stdout.writeln('removed');
        }
      }
      return 0;
    default:
      stderr.writeln('unknown command');
      return 1;
  }
}

void main(List<String> args) {
  try {
    exitCode = run(args);
  } on HResultException catch (e) {
    stderr.writeln(e);
    exitCode = 2;
  } catch (e) {
    stderr.writeln('$e');
    exitCode = 2;
  }
}
