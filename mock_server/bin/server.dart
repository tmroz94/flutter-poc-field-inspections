import 'dart:io';

import 'package:args/args.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Usage: dart run bin/server.dart [--port 8080] [--host 0.0.0.0] [--delay 300]
///
/// Bind to 0.0.0.0 so the Android emulator (10.0.2.2) and phones on the same
/// network can reach it.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: Platform.environment['PORT'] ?? '8080')
    ..addOption('host', defaultsTo: '0.0.0.0')
    ..addOption('delay', defaultsTo: '300', help: 'Default latency in ms')
    ..addFlag('quiet', negatable: false, help: 'No request log');
  final opts = parser.parse(args);

  var handler = buildHandler(defaultDelay: Duration(milliseconds: int.parse(opts['delay'] as String)));
  if (!(opts['quiet'] as bool)) handler = const Pipeline().addMiddleware(logRequests()).addHandler(handler);

  final server = await io.serve(handler, opts['host'] as String, int.parse(opts['port'] as String));
  stdout.writeln('Mock API listening on http://${server.address.host}:${server.port}/api');
}
