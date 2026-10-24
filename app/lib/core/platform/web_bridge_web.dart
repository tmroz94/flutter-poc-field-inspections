import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves [bytes] as a download: a Blob URL on a temporary `<a download>`.
void downloadBytes(Uint8List bytes, String fileName, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Listens for Ctrl/Cmd+V of images (screenshots, copied photos) on the page.
void Function() listenForPastedImages(void Function(Uint8List bytes, String name, String mime) onImage) {
  void handler(web.ClipboardEvent event) {
    final items = event.clipboardData?.items;
    if (items == null) return;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file' || !item.type.startsWith('image/')) continue;
      final file = item.getAsFile();
      if (file == null) continue;
      file.arrayBuffer().toDart.then((buffer) {
        final ext = item.type.split('/').last;
        onImage(buffer.toDart.asUint8List(), 'pasted-${DateTime.now().millisecondsSinceEpoch}.$ext', item.type);
      });
    }
  }

  final listener = handler.toJS;
  web.document.addEventListener('paste', listener);
  return () => web.document.removeEventListener('paste', listener);
}
