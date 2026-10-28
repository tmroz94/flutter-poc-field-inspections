import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final link = Uri.parse('https://fieldinspections.example/inspections/INS-1042');
  late List<String> copied;

  setUp(() {
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  test('web: no mailto fallback, so a browser without Web Share copies the link', () async {
    ShareParams? sent;
    final service = ShareService(
      sharer: (params) async {
        sent = params;
        throw Exception('navigator.share unavailable');
      },
    );
    final outcome = await service.shareLink(
      text: 'Riverside',
      link: link,
      caps: const Capabilities(isWeb: true, platform: TargetPlatform.macOS),
    );
    expect(sent?.mailToFallbackEnabled, isFalse);
    expect(outcome, ShareOutcome.copied);
    expect(copied, [link.toString()]);
  });

  test('Linux copies the link instead of opening a mail composer', () async {
    var calls = 0;
    final service = ShareService(
      sharer: (params) async {
        calls++;
        return const ShareResult('', ShareResultStatus.unavailable);
      },
    );
    final outcome = await service.shareLink(
      text: 'Riverside',
      link: link,
      caps: const Capabilities(isWeb: false, platform: TargetPlatform.linux),
    );
    expect(calls, 0);
    expect(outcome, ShareOutcome.copied);
    expect(copied, [link.toString()]);
  });

  test('a share sheet that shares or is dismissed says so', () async {
    const android = Capabilities(isWeb: false, platform: TargetPlatform.android);
    var status = ShareResultStatus.success;
    final service = ShareService(sharer: (params) async => ShareResult('', status));
    expect(await service.shareLink(text: 'x', link: link, caps: android), ShareOutcome.shared);
    status = ShareResultStatus.dismissed;
    expect(await service.shareLink(text: 'x', link: link, caps: android), ShareOutcome.dismissed);
    expect(copied, isEmpty);
  });
}
