// Runs the Android device tests, including the ones that need the host to
// change the device (network, GPS). From the repo root, with an emulator or
// phone connected:
//   fvm dart tool/android_device_tests.dart [--device emulator-5554] [--only host]
//   fvm dart tool/android_device_tests.dart --patrol [--only native|kill]
//
// Default: starts the mock API on port 8080 when nothing answers there (or
// resets the one that does to its fixtures), runs `flutter test` for
// app/integration_test, and executes the `HOST> …` lines the tests print (see
// app/integration_test/host_test.dart). Only the commands below are accepted;
// anything else, or an adb command that fails, fails the run.
//
// --patrol: runs app/patrol_test with Patrol (needs `dart pub global activate
// patrol_cli` and a JDK, e.g. Android Studio's). The device gets a test photo
// and a screen-lock PIN for the duration; afterwards the helper checks that
// tapping a notification cold-starts the killed app on its route.
//
// The device is restored (airplane mode off, test GPS provider removed, PIN
// and test photo removed) when the run ends, also on Ctrl+C or SIGTERM.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _package = 'dev.flutterpoc.field_inspections';

/// FVM when installed (it pins the SDK from .fvmrc), else null: CI runners
/// install that same Flutter version and put flutter/dart on PATH.
final String? _fvm = () {
  if (Process.runSync(Platform.isWindows ? 'where' : 'which', ['fvm'], runInShell: true).exitCode == 0) return 'fvm';
  const local = r'D:\tools\fvm\fvm.exe';
  return Platform.isWindows && File(local).existsSync() ? local : null;
}();

/// Runs `flutter …` / `dart …` through FVM when there is one. Through the
/// shell on Windows: `flutter`, and an FVM installed with `dart pub global
/// activate`, are .bat shims there, which Process can't start directly.
Future<Process> _sdkStart(List<String> cmd, {String? workingDirectory, Map<String, String>? environment}) {
  final fvm = _fvm;
  return fvm != null
      ? Process.start(fvm, cmd, workingDirectory: workingDirectory, environment: environment, runInShell: Platform.isWindows)
      : Process.start(
          cmd.first,
          cmd.sublist(1),
          workingDirectory: workingDirectory,
          environment: environment,
          runInShell: Platform.isWindows,
        );
}

Future<ProcessResult> _sdkRun(List<String> cmd, {String? workingDirectory}) {
  final fvm = _fvm;
  return fvm != null
      ? Process.run(fvm, cmd, workingDirectory: workingDirectory, runInShell: Platform.isWindows)
      : Process.run(cmd.first, cmd.sublist(1), workingDirectory: workingDirectory, runInShell: Platform.isWindows);
}

String get _adb {
  final env = Platform.environment;
  for (final sdk in [env['ANDROID_HOME'], env['ANDROID_SDK_ROOT'], if (env['LOCALAPPDATA'] case final l?) '$l\\Android\\Sdk']) {
    if (sdk == null) continue;
    final exe = File('$sdk/platform-tools/adb${Platform.isWindows ? '.exe' : ''}');
    if (exe.existsSync()) return exe.path;
  }
  return 'adb';
}

/// Runs `adb -s <device> <args>` and returns its output. A non-zero exit code
/// throws, unless [allowFailure] (probes such as `pidof`, best-effort steps).
Future<String> _adbRun(String device, List<String> args, {bool quiet = false, bool allowFailure = false}) async {
  // adb writes UTF-8; the default (the system code page on Windows) would
  // garble the en dash in the notification text the kill test looks for.
  final r = await Process.run(_adb, ['-s', device, ...args], stdoutEncoding: utf8, stderrEncoding: utf8);
  final out = '${r.stdout}${r.stderr}'.trim();
  if (!quiet || (r.exitCode != 0 && !allowFailure)) stdout.writeln('[host] adb ${args.join(' ')} → exit ${r.exitCode} $out');
  if (r.exitCode != 0 && !allowFailure) throw StateError('adb ${args.join(' ')} failed (exit ${r.exitCode})');
  return out;
}

// ---- Clean-up on exit and on signals ----

/// Steps that undo what the run changed, newest last; [_runCleanups] runs them
/// newest first. Keyed so a step registers once.
final _cleanups = <String, Future<void> Function()>{};
Future<bool>? _cleaning;

/// Runs every registered clean-up step, even when one fails; false when any
/// step failed. Callers that arrive while it runs wait for the same run.
Future<bool> _runCleanups() {
  final running = _cleaning;
  if (running != null) return running;
  final run = _cleanUp();
  _cleaning = run;
  unawaited(run.whenComplete(() => _cleaning = null));
  return run;
}

Future<bool> _cleanUp() async {
  var ok = true;
  for (final MapEntry(key: name, value: step) in _cleanups.entries.toList().reversed) {
    _cleanups.remove(name);
    try {
      await step();
    } on Object catch (e) {
      ok = false;
      stdout.writeln('[host] FAIL: clean-up "$name": $e');
    }
  }
  return ok;
}

/// Ctrl+C (and SIGTERM, e.g. a cancelled CI job) restores the device before
/// exiting. A second Ctrl+C during the clean-up exits at once.
void _restoreOnSignals() {
  for (final signal in [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      if (_cleaning != null) exit(130);
      stdout.writeln('\n[host] $signal: restoring the device before exiting');
      await _runCleanups();
      exit(signal == ProcessSignal.sigint ? 130 : 143);
    });
  }
}

/// Ends [process] and its children: FVM runs the SDK's dart or flutter as a
/// child process, which killing FVM alone would leave running (the mock API
/// would keep :8080).
void _killTree(Process process) {
  if (Platform.isWindows) {
    Process.runSync('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
  } else {
    for (final pid in _descendants(process.pid).reversed) {
      Process.killPid(pid);
    }
    process.kill();
  }
}

/// Child processes of [pid] and theirs, parents before children (pgrep, macOS and Linux).
List<int> _descendants(int pid) {
  final r = Process.runSync('pgrep', ['-P', '$pid']);
  final children = [for (final line in '${r.stdout}'.split('\n')) ?int.tryParse(line.trim())];
  return [
    for (final c in children) ...[c, ..._descendants(c)],
  ];
}

var _mockLocation = false;

/// Removes the test location provider and the shell's mock-location right.
Future<void> _restoreLocation(String device) async {
  if (!_mockLocation) return;
  _mockLocation = false;
  await _all([
    () => _adbRun(device, ['shell', 'cmd', 'location', 'providers', 'remove-test-provider', 'gps']),
    () => _adbRun(device, ['shell', 'appops', 'set', 'com.android.shell', 'android:mock_location', 'default']),
  ]);
}

/// Runs every step even when one fails, then throws the collected errors.
Future<void> _all(List<Future<Object?> Function()> steps) async {
  final errors = <Object>[];
  for (final step in steps) {
    try {
      await step();
    } on Object catch (e) {
      errors.add(e);
    }
  }
  if (errors.isNotEmpty) throw StateError(errors.join('; '));
}

/// The whitelisted host commands the tests may ask for.
Future<void> _hostCommand(String device, String line) async {
  final parts = line.trim().split(RegExp(r'\s+'));
  switch (parts) {
    case ['airplane', final s] when s == 'on' || s == 'off':
      if (s == 'on') _cleanups['airplane mode'] ??= () => _hostCommand(device, 'airplane off');
      await _adbRun(device, ['shell', 'cmd', 'connectivity', 'airplane-mode', s == 'on' ? 'enable' : 'disable']);
    case ['location', final s] when s == 'grant' || s == 'revoke':
      for (final p in ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']) {
        await _adbRun(device, ['shell', 'pm', s, _package, 'android.permission.$p']);
      }
    case ['geo', final lat, final lng] when double.tryParse(lat) != null && double.tryParse(lng) != null:
      // Android's test location provider (emulators and phones alike). The
      // emulator's own `geo fix` didn't reach the location stack on API 37.
      if (!_mockLocation) {
        _mockLocation = true;
        _cleanups['test GPS provider'] ??= () => _restoreLocation(device);
        await _adbRun(device, ['shell', 'appops', 'set', 'com.android.shell', 'android:mock_location', 'allow']);
        // Left over if an earlier run was killed; adding it again would fail.
        await _adbRun(device, ['shell', 'cmd', 'location', 'providers', 'remove-test-provider', 'gps'], quiet: true, allowFailure: true);
        await _adbRun(device, ['shell', 'cmd', 'location', 'providers', 'add-test-provider', 'gps']);
        await _adbRun(device, ['shell', 'cmd', 'location', 'providers', 'set-test-provider-enabled', 'gps', 'true']);
      }
      await _adbRun(device, [
        'shell',
        'cmd',
        'location',
        'providers',
        'set-test-provider-location',
        'gps',
        '--location',
        '$lat,$lng',
        '--accuracy',
        '5',
      ]);
    default:
      throw StateError('Unknown host command: $line');
  }
}

const _api = 'http://localhost:8080/api';

/// Sends a request to the mock API; true when it answers 200.
Future<bool> _apiOk(String method, String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final res = await (await client.openUrl(method, Uri.parse('$_api$path'))).close();
    await res.drain<void>();
    return res.statusCode == 200;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _apiUp() => _apiOk('GET', '/health');

// ---- Patrol ----

const _pin = '1111';
const _photo = '/sdcard/Pictures/fi_test_photo.png';
const _notifyButton = 'Notification for Inspection detail'; // deep-link tester row
const _notifyRoute = '/inspections/INS-1042?tab=checklist'; // that row's example
const _notifyScreenText = 'Warehouse A – loading dock'; // INS-1042

/// A 256×256 PNG in the app's primary colour (no image library needed).
Uint8List _png() {
  const w = 256;
  final raw = BytesBuilder();
  for (var y = 0; y < w; y++) {
    raw.addByte(0);
    for (var x = 0; x < w; x++) {
      raw.add(const [103, 80, 164]);
    }
  }
  int crc(List<int> bytes) {
    var c = 0xffffffff;
    for (final b in bytes) {
      c ^= b;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
      }
    }
    return c ^ 0xffffffff;
  }

  Uint8List u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
  Uint8List chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return (BytesBuilder()
          ..add(u32(data.length))
          ..add(body)
          ..add(u32(crc(body))))
        .takeBytes();
  }

  final header = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, w)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        ..add(chunk('IHDR', header.buffer.asUint8List()))
        ..add(chunk('IDAT', zlib.encode(raw.takeBytes())))
        ..add(chunk('IEND', const [])))
      .takeBytes();
}

Future<void> _rescanMedia(String device) => _adbRun(device, [
  'shell',
  'content',
  'call',
  '--method',
  'scan_volume',
  '--uri',
  'content://media',
  '--arg',
  'external_primary',
], quiet: true);

/// A photo for the gallery test and a PIN for the device-credential prompt.
/// Registers their removal first, so even a half-done preparation is undone.
Future<void> _preparePatrol(String device) async {
  _cleanups['test photo'] ??= () async {
    await _adbRun(device, ['shell', 'rm', '-f', _photo]);
    await _rescanMedia(device);
  };
  final file = File('${Directory.systemTemp.path}/fi_test_photo.png')..writeAsBytesSync(_png());
  await _adbRun(device, ['push', file.path, _photo]);
  await _rescanMedia(device);
  // Fails when the device already has a screen lock; the helper never clears one it didn't set.
  await _adbRun(device, ['shell', 'locksettings', 'set-pin', _pin]);
  _cleanups['screen-lock PIN'] ??= () => _adbRun(device, ['shell', 'locksettings', 'clear', '--old', _pin]);
}

/// Patrol's Gradle run needs a JDK: JAVA_HOME, else Android Studio's bundled one.
Map<String, String> _patrolEnv() {
  final env = Map.of(Platform.environment);
  if (env['JAVA_HOME'] == null) {
    for (final jbr in [
      r'C:\Program Files\Android\Android Studio\jbr',
      '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      '/opt/android-studio/jbr',
    ]) {
      if (Directory(jbr).existsSync()) {
        env['JAVA_HOME'] = jbr;
        env['PATH'] = '$jbr${Platform.pathSeparator}bin${Platform.isWindows ? ';' : ':'}${env['PATH']}';
        break;
      }
    }
  }
  // Patrol calls adb by name.
  final adb = File(_adb);
  if (adb.existsSync()) env['PATH'] = '${adb.parent.path}${Platform.isWindows ? ';' : ':'}${env['PATH']}';
  env['PATROL_FLUTTER_COMMAND'] = _fvm == null ? 'flutter' : '$_fvm flutter';
  return env;
}

Future<int> _runPatrol(String device, String target, {bool uninstall = true}) async {
  final p = await _sdkStart(
    [
      'dart',
      'pub',
      'global',
      'run',
      'patrol_cli:main',
      'test',
      '-t',
      target,
      '--device',
      device,
      '--dart-define=TEST_PIN=$_pin',
      if (!uninstall) '--no-uninstall',
    ],
    workingDirectory: 'app',
    environment: _patrolEnv(),
  );
  p.stdout.transform(utf8.decoder).listen(stdout.write);
  p.stderr.transform(utf8.decoder).listen(stderr.write);
  return p.exitCode;
}

/// Polls [check] every second until it returns true or [seconds] pass.
Future<bool> _poll(int seconds, Future<bool> Function() check) async {
  for (var i = 0; i < seconds; i++) {
    if (await check()) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

/// The UI tree as uiautomator sees it (Flutter exposes its semantics to it).
/// Transient failures (no idle state yet) return an empty or partial dump;
/// callers poll.
Future<String> _uiDump(String device) async {
  await _adbRun(device, ['shell', 'uiautomator', 'dump', '/sdcard/fi_ui.xml'], quiet: true, allowFailure: true);
  return _adbRun(device, ['shell', 'cat', '/sdcard/fi_ui.xml'], quiet: true, allowFailure: true);
}

/// The real app (not Patrol's test-bundle build, whose entry point waits for
/// the test runner).
Future<String?> _buildAppApk() async {
  final r = await _sdkRun(['flutter', 'build', 'apk', '--debug'], workingDirectory: 'app');
  final built = File('app/build/app/outputs/flutter-apk/app-debug.apk');
  if (r.exitCode != 0 || !built.existsSync()) {
    stdout.writeln('[host] FAIL: building the app APK\n${r.stdout}${r.stderr}');
    return null;
  }
  return built.copySync('${Directory.systemTemp.path}${Platform.pathSeparator}fi_app_debug.apk').path;
}

/// Centre of the first node whose text or content-desc (how Flutter exposes
/// its semantics to uiautomator) equals [label].
(int, int)? _find(String dump, String label) {
  final escaped = RegExp.escape(const HtmlEscape(HtmlEscapeMode.attribute).convert(label));
  final m = RegExp('(?:text|content-desc)="$escaped"[^>]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"').firstMatch(dump);
  if (m == null) return null;
  final b = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
  return ((b[0] + b[2]) ~/ 2, (b[1] + b[3]) ~/ 2);
}

/// Waits up to [seconds] for [label] (scrolling down when [scroll]) and taps it.
Future<bool> _tapLabel(String device, String label, {int seconds = 20, bool scroll = false}) async {
  (int, int)? at;
  final found = await _poll(seconds, () async {
    at = _find(await _uiDump(device), label);
    if (at == null && scroll) await _adbRun(device, ['shell', 'input', 'swipe', '540', '1800', '540', '900', '300'], quiet: true);
    return at != null;
  });
  if (!found) {
    stdout.writeln('[host] FAIL: "$label" not on screen');
    return false;
  }
  await _adbRun(device, ['shell', 'input', 'tap', '${at!.$1}', '${at!.$2}']);
  return true;
}

/// Tapping a notification after the app was killed, with the real app: the
/// deep-link tester schedules one (15 s), the process is killed the way
/// Android does under memory pressure, and the tap must cold-start the app on
/// the notification's route.
Future<bool> _notificationAfterKill(String device, String appApk) async {
  // pidof exits 1 when the process isn't running.
  Future<bool> running() async => (await _adbRun(device, ['shell', 'pidof', _package], quiet: true, allowFailure: true)).isNotEmpty;
  await _adbRun(device, ['uninstall', _package], quiet: true, allowFailure: true);
  _cleanups['app install'] ??= () => _adbRun(device, ['uninstall', _package], quiet: true, allowFailure: true);
  await _adbRun(device, ['install', appApk]);
  await _adbRun(device, ['shell', 'pm', 'grant', _package, 'android.permission.POST_NOTIFICATIONS']);
  await _adbRun(device, [
    'shell',
    'am',
    'start',
    '-a',
    'android.intent.action.VIEW',
    '-d',
    'fieldinspections://app/settings/poc/deep-links',
  ]);
  var ok = await _tapLabel(device, 'Use demo account', seconds: 30) && await _tapLabel(device, _notifyButton, scroll: true);
  if (ok) {
    await Future<void>.delayed(const Duration(seconds: 1));
    await _adbRun(device, ['shell', 'input', 'keyevent', 'KEYCODE_HOME']);
    await Future<void>.delayed(const Duration(seconds: 2));
    // `am kill` ends a background process and keeps its scheduled alarms
    // (force-stop would cancel them); run-as kill is the fallback.
    await _adbRun(device, ['shell', 'am', 'kill', _package]);
    if (await running()) {
      final pid = await _adbRun(device, ['shell', 'pidof', _package], quiet: true, allowFailure: true);
      await _adbRun(device, ['shell', 'run-as', _package, 'kill', '-9', pid], allowFailure: true);
    }
    ok = await _poll(5, () async => !await running());
    stdout.writeln(ok ? '[host] app process killed; waiting for the notification' : '[host] FAIL: the app process is still running');
  }
  if (ok) {
    ok = await _poll(
      60,
      () async => (await _adbRun(device, ['shell', 'dumpsys', 'notification', '--noredact'], quiet: true)).contains(_notifyRoute),
    );
    if (!ok) stdout.writeln('[host] FAIL: the notification never arrived');
  }
  if (ok) {
    await _adbRun(device, ['shell', 'cmd', 'statusbar', 'expand-notifications']);
    ok = await _tapLabel(device, 'Test link');
  }
  if (ok) {
    var screen = '';
    ok = await _poll(30, () async => (screen = await _uiDump(device)).contains(_notifyScreenText));
    if (ok) {
      stdout.writeln('[host] PASS: the tap cold-started the app on $_notifyRoute');
    } else {
      final shown = RegExp(r'(?:text|content-desc)="([^"]+)"').allMatches(screen).map((m) => m.group(1)).take(15).join(' | ');
      stdout.writeln('[host] FAIL: the route was not shown after the tap. On screen: $shown');
    }
  }
  if (!ok) {
    final shot = '${Directory.systemTemp.path}${Platform.pathSeparator}fi_notification_fail.png';
    await _adbRun(device, ['shell', 'screencap', '-p', '/sdcard/fi_fail.png'], quiet: true, allowFailure: true);
    await _adbRun(device, ['pull', '/sdcard/fi_fail.png', shot], quiet: true, allowFailure: true);
    stdout.writeln('[host] screenshot: $shot');
  }
  await _adbRun(device, ['uninstall', _package], quiet: true, allowFailure: true);
  _cleanups.remove('app install');
  return ok;
}

/// [only]: `native` or `kill` runs just that part.
Future<int> _patrolMain(String device, String? only) async {
  var native = 1;
  var tapped = false;
  try {
    await _preparePatrol(device);
    native = only == 'kill' ? 0 : await _runPatrol(device, 'patrol_test/native_test.dart');
    tapped = true;
    if (only != 'native') {
      final appApk = await _buildAppApk();
      tapped = appApk != null && await _notificationAfterKill(device, appApk);
    }
  } on Object catch (e) {
    stdout.writeln('[host] FAIL: $e');
    tapped = false;
  }
  final cleaned = await _runCleanups();
  stdout.writeln('[host] native tests: ${native == 0 ? 'passed' : 'failed'} · notification after kill: ${tapped ? 'passed' : 'failed'}');
  return native == 0 && tapped && cleaned ? 0 : 1;
}

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final device = opt('device') ?? 'emulator-5554';
  final only = opt('only');
  _restoreOnSignals();
  if (args.contains('--patrol')) exit(await _patrolMain(device, only));
  final target = only == null ? 'integration_test' : 'integration_test/${only}_test.dart';

  if (await _apiUp()) {
    // Someone else's server (another run, a manual one): start from the fixtures.
    if (!await _apiOk('POST', '/admin/reset')) {
      stdout.writeln('[host] FAIL: something answers $_api/health but the reset failed; stop it or free port 8080');
      exit(1);
    }
    stdout.writeln('[host] reusing the mock API on :8080 (reset to its fixtures)');
  } else {
    stdout.writeln('[host] starting the mock API on :8080');
    final deps = await _sdkRun(['dart', 'pub', 'get'], workingDirectory: 'mock_server');
    if (deps.exitCode != 0) stdout.writeln('[host] dart pub get in mock_server failed:\n${deps.stdout}${deps.stderr}');
    final server = await _sdkStart(['dart', 'run', 'mock_server/bin/server.dart', '--port', '8080', '--quiet']);
    _cleanups['mock API'] = () async => _killTree(server);
    // Read its output so a full pipe can never block it; errors show with a prefix.
    for (final (stream, sink) in [(server.stdout, stdout), (server.stderr, stderr)]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen((l) => sink.writeln('[mock] $l'));
    }
    final up = await _poll(30, _apiUp);
    if (!up) {
      stdout.writeln('[host] FAIL: the mock API did not start on :8080');
      await _runCleanups();
      exit(1);
    }
  }

  final test = await _sdkStart(['flutter', 'test', target, '-d', device, '--dart-define=HOST_HELPER=true'], workingDirectory: 'app');
  _cleanups['flutter test'] = () async => _killTree(test);
  var failed = false;
  // Host commands run one at a time, in the order the tests print them.
  var queue = Future<void>.value();
  final out = test.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    stdout.writeln(line);
    final i = line.indexOf('HOST> ');
    if (i >= 0) {
      queue = queue.then((_) => _hostCommand(device, line.substring(i + 6))).catchError((Object e) {
        stdout.writeln('[host] $e');
        failed = true;
      });
    }
  });
  test.stderr.transform(utf8.decoder).listen(stderr.write);
  final code = await test.exitCode;
  _cleanups.remove('flutter test');
  // Let the last lines through; a child that inherited the pipe may keep it open.
  await out.asFuture<void>().timeout(const Duration(seconds: 5), onTimeout: () {});
  await out.cancel();
  await queue;

  // Never leave the device offline or on a fake position, nor the server running.
  final cleaned = await _runCleanups();
  exit(code != 0 || failed || !cleaned ? 1 : 0);
}
