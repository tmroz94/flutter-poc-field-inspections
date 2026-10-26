import 'dart:io';

import 'package:args/args.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Usage: dart run bin/server.dart [--port 8080] [--host 127.0.0.1] [--delay 300]
///
/// The default host, 127.0.0.1, is enough for this machine's browser, the iOS
/// simulator and the Android emulator (its 10.0.2.2 is the host's loopback).
/// Pass `--host 0.0.0.0` only to reach it from a phone on the same network:
/// anyone on that network can then use it (no real auth, CORS open to all).
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: Platform.environment['PORT'] ?? '8080')
    ..addOption('host', defaultsTo: '127.0.0.1', help: 'Interface to bind; 0.0.0.0 for phones on the same network')
    ..addOption('delay', defaultsTo: '300', help: 'Default latency in ms')
    ..addFlag('quiet', negatable: false, help: 'No request log');
  final opts = parser.parse(args);

  var handler = buildHandler(defaultDelay: Duration(milliseconds: int.parse(opts['delay'] as String)));
  if (!(opts['quiet'] as bool)) handler = const Pipeline().addMiddleware(logRequests()).addHandler(handler);

  final server = await io.serve(handler, opts['host'] as String, int.parse(opts['port'] as String));
  stdout.writeln('Mock API listening on http://${server.address.host}:${server.port}/api');
}
