// Runs the Android device tests, including the ones that need the host to
// change the device (network, GPS). From the repo root, with an emulator or
// phone connected:
//   fvm dart tool/android_device_tests.dart [--device emulator-5554] [--only host]
//
// It starts the mock API on port 8080 when nothing answers there, runs
// `flutter test` for app/integration_test, and executes the `HOST> …` lines the
// tests print (see app/integration_test/host_test.dart). Only the commands below
// are accepted; anything else fails the run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _package = 'dev.flutterpoc.field_inspections';

String get _fvm {
  final local = Platform.isWindows ? r'D:\tools\fvm\fvm.exe' : '';
  final onPath = Process.runSync(Platform.isWindows ? 'where' : 'which', ['fvm'], runInShell: true).exitCode == 0;
  return onPath || local.isEmpty || !File(local).existsSync() ? 'fvm' : local;
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

Future<void> _adbRun(String device, List<String> args) async {
  final r = await Process.run(_adb, ['-s', device, ...args]);
  stdout.writeln('[host] adb ${args.join(' ')} → exit ${r.exitCode} ${'${r.stdout}${r.stderr}'.trim()}');
}

var _mockLocation = false;

/// Removes the test location provider and the shell's mock-location right.
Future<void> _restoreLocation(String device) async {
  if (!_mockLocation) return;
  await _adbRun(device, ['shell', 'cmd', 'location', 'providers', 'remove-test-provider', 'gps']);
  await _adbRun(device, ['shell', 'appops', 'set', 'com.android.shell', 'android:mock_location', 'default']);
}

/// The whitelisted host commands the tests may ask for.
Future<void> _hostCommand(String device, String line) async {
  final parts = line.trim().split(RegExp(r'\s+'));
  switch (parts) {
    case ['airplane', final s] when s == 'on' || s == 'off':
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
        await _adbRun(device, ['shell', 'appops', 'set', 'com.android.shell', 'android:mock_location', 'allow']);
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

Future<bool> _apiUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    final res = await (await client.getUrl(Uri.parse('http://localhost:8080/api/health'))).close();
    client.close();
    return res.statusCode == 200;
  } on Object {
    return false;
  }
}

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final device = opt('device') ?? 'emulator-5554';
  final only = opt('only');
  final target = only == null ? 'integration_test' : 'integration_test/${only}_test.dart';

  Process? server;
  if (!await _apiUp()) {
    stdout.writeln('[host] starting the mock API on :8080');
    server = await Process.start(_fvm, ['dart', 'run', 'mock_server/bin/server.dart', '--port', '8080']);
    for (var i = 0; i < 60 && !await _apiUp(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  final test = await Process.start(_fvm, [
    'flutter',
    'test',
    target,
    '-d',
    device,
    '--dart-define=HOST_HELPER=true',
  ], workingDirectory: 'app');
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
  await out.cancel();
  await queue;

  // Never leave the device offline or on a fake position.
  await _hostCommand(device, 'airplane off');
  await _restoreLocation(device);
  server?.kill();
  exit(code != 0 || failed ? 1 : 0);
}
