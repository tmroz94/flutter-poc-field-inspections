import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Collects engine frame timings from app start so Diagnostics can compare
/// renderers (Impeller, CanvasKit, Skwasm) on real devices: average build and
/// raster time, and the share of frames over the display's frame budget.
///
/// Build (UI thread) and raster (raster thread) run in parallel, so a frame
/// is late when the slower of the two exceeds the budget, not their sum.
/// Listeners hear about new numbers at most once a second, so a screen that
/// shows them doesn't keep itself rendering every frame.
class FrameStats extends ChangeNotifier {
  FrameStats._();

  static final instance = FrameStats._();

  int frames = 0;
  int slow = 0;
  Duration _build = Duration.zero;
  Duration _raster = Duration.zero;
  bool _started = false;
  DateTime _notifiedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// One frame at the display's refresh rate (60 Hz when unknown).
  Duration budget = const Duration(microseconds: 16667);

  void start() {
    if (_started) return;
    _started = true;
    final binding = SchedulerBinding.instance;
    final displays = binding.platformDispatcher.displays;
    final hz = displays.isEmpty ? 0.0 : displays.first.refreshRate;
    if (hz > 0) budget = Duration(microseconds: (1e6 / hz).round());
    binding.addTimingsCallback(_record);
  }

  void _record(List<FrameTiming> timings) {
    for (final t in timings) {
      frames++;
      _build += t.buildDuration;
      _raster += t.rasterDuration;
      final slower = t.buildDuration > t.rasterDuration ? t.buildDuration : t.rasterDuration;
      if (slower > budget) slow++;
    }
    final now = DateTime.now();
    if (now.difference(_notifiedAt) >= const Duration(seconds: 1)) {
      _notifiedAt = now;
      notifyListeners();
    }
  }

  double get avgBuildMs => frames == 0 ? 0 : _build.inMicroseconds / frames / 1000;
  double get avgRasterMs => frames == 0 ? 0 : _raster.inMicroseconds / frames / 1000;
  double get slowPercent => frames == 0 ? 0 : slow * 100 / frames;
  double get budgetMs => budget.inMicroseconds / 1000;

  void reset() {
    frames = 0;
    slow = 0;
    _build = Duration.zero;
    _raster = Duration.zero;
    notifyListeners();
  }
}
