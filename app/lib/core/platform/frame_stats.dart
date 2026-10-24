import 'package:flutter/scheduler.dart';

/// Collects engine frame timings from app start so Diagnostics can compare
/// renderers (Impeller, CanvasKit, Skwasm) on real devices: average build and
/// raster time, and the share of frames over the 60 Hz budget.
class FrameStats {
  FrameStats._();

  static final instance = FrameStats._();

  static const _budget = Duration(microseconds: 16667);

  int frames = 0;
  int slow = 0;
  Duration _build = Duration.zero;
  Duration _raster = Duration.zero;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_record);
  }

  void _record(List<FrameTiming> timings) {
    for (final t in timings) {
      frames++;
      _build += t.buildDuration;
      _raster += t.rasterDuration;
      if (t.buildDuration + t.rasterDuration > _budget) slow++;
    }
  }

  double get avgBuildMs => frames == 0 ? 0 : _build.inMicroseconds / frames / 1000;
  double get avgRasterMs => frames == 0 ? 0 : _raster.inMicroseconds / frames / 1000;
  double get slowPercent => frames == 0 ? 0 : slow * 100 / frames;

  void reset() {
    frames = 0;
    slow = 0;
    _build = Duration.zero;
    _raster = Duration.zero;
  }
}
