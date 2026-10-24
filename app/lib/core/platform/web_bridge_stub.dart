import 'dart:typed_data';

/// Saves [bytes] as a download (web only).
void downloadBytes(Uint8List bytes, String fileName, String mime) => throw UnsupportedError('downloadBytes is web-only');

/// Calls [onImage] for images pasted anywhere on the page (web only).
/// Returns a function that stops listening.
void Function() listenForPastedImages(void Function(Uint8List bytes, String name, String mime) onImage) => () {};
