import 'dart:io';

import 'package:args/args.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Usage: dart run bin/server.dart [--port 8080] [--host 127.0.0.1] [--delay 300] [--allow-origin <origin>]
///
/// The default host, 127.0.0.1, is enough for this machine's browser, the iOS
/// simulator and the Android emulator (its 10.0.2.2 is the host's loopback).
/// Pass `--host 0.0.0.0` only to reach it from a phone on the same network:
/// anyone on that network can then use it (no real auth). Browsers may call
/// it only from this machine's pages; `--allow-origin` adds another.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: Platform.environment['PORT'] ?? '8080')
    ..addOption('host', defaultsTo: '127.0.0.1', help: 'Interface to bind; 0.0.0.0 for phones on the same network')
    ..addOption('delay', defaultsTo: '300', help: 'Default latency in ms')
    ..addMultiOption('allow-origin', help: 'Another web origin that may call the API, e.g. http://192.168.1.20:5173')
    ..addFlag('quiet', negatable: false, help: 'No request log');
  final opts = parser.parse(args);

  final host = opts['host'] as String;
  var handler = buildHandler(
    defaultDelay: Duration(milliseconds: int.parse(opts['delay'] as String)),
    allowedOrigins: (opts['allow-origin'] as List<String>).toSet(),
    // Bound to every interface, phones reach it by the machine's network
    // address, so any Host goes; otherwise only this machine's names.
    allowedHosts: host == '0.0.0.0' || host == '::' ? null : {...localHosts, host},
  );
  if (!(opts['quiet'] as bool)) handler = const Pipeline().addMiddleware(logRequests()).addHandler(handler);

  final server = await io.serve(handler, host, int.parse(opts['port'] as String));
  stdout.writeln('Mock API listening on http://${server.address.host}:${server.port}/api');
}
