import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_typography.dart';
import '../../application/errors/user_error_message.dart';

/// 支持相机的平台在草稿区直接取景，失败时保留草稿并允许选择文件。
class PhotoCapturePanel extends StatefulWidget {
  const PhotoCapturePanel({
    super.key,
    required this.title,
    required this.onConfirmed,
    required this.onChooseFile,
    required this.onCancel,
    this.fullScreen = false,
    this.onBack,
  });

  final String title;
  final Future<void> Function(Uint8List bytes, DateTime capturedAt) onConfirmed;
  final VoidCallback onChooseFile;
  final VoidCallback onCancel;
  final bool fullScreen;
  final VoidCallback? onBack;

  @override
  State<PhotoCapturePanel> createState() => _PhotoCapturePanelState();
}

class _PhotoCapturePanelState extends State<PhotoCapturePanel>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Uint8List? _capture;
  DateTime? _capturedAt;
  String? _error;
  bool _busy = false;
  bool _confirming = false;
  int _generation = 0;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _gestureStartZoom = 1;
  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('设备没有可用相机');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      next = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      var minZoom = 1.0;
      var maxZoom = 1.0;
      try {
        minZoom = await next.getMinZoomLevel();
        maxZoom = await next.getMaxZoomLevel();
      } on Object {
        // 相机无变焦能力时仍可正常取景和拍照。
      }
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
        _focusPoint = null;
      });
    } on CameraException catch (error) {
      await next?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              const {
                'CameraAccessDenied',
                'CameraAccessDeniedWithoutPrompt',
                'CameraAccessRestricted',
              }.contains(error.code)
              ? '相机权限未授予。可在系统设置中授权，或直接选择图片文件。'
              : '相机暂时无法启动，请重试或选择图片文件',
        );
      }
    } catch (error) {
      await next?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = userErrorMessage(error, fallback: '相机无法启动，请重试或选择图片文件'),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _generation++;
      final previous = _controller;
      _controller = null;
      _busy = _confirming; // 返回前台可重新取景；保存中的照片仍锁定，避免重复加入。
      if (previous != null) unawaited(previous.dispose());
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _capture == null &&
        !_busy) {
      unawaited(_start());
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    final generation = _generation;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        throw ArgumentError('照片必须非空且不能超过 20 MiB');
      }
      if (mounted && generation == _generation) {
        setState(() {
          _capture = bytes;
          _capturedAt = DateTime.now().toUtc();
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = userErrorMessage(error, fallback: '拍照失败，请重试或选择图片文件'),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
    if (mounted &&
        generation == _generation &&
        widget.fullScreen &&
        _capture != null) {
      await _confirm();
    }
  }

  Future<void> _confirm() async {
    final bytes = _capture;
    final capturedAt = _capturedAt;
    if (_busy || _confirming || bytes == null || capturedAt == null) return;
    _confirming = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirmed(bytes, capturedAt);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = userErrorMessage(error, fallback: '照片加入草稿失败，照片已保留，请重试'),
        );
      }
    } finally {
      _confirming = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retake() {
    setState(() {
      _capture = null;
      _capturedAt = null;
      _error = null;
    });
    if (_controller == null) unawaited(_start());
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null || _busy || _maxZoom <= _minZoom) return;
    final nextZoom = zoom.clamp(_minZoom, _maxZoom).toDouble();
    setState(() => _zoom = nextZoom);
    try {
      await controller.setZoomLevel(nextZoom);
    } on CameraException {
      if (mounted) setState(() => _error = '此设备暂不支持调整变焦');
    }
  }

  Future<void> _focusAt(Offset localPosition, Size size) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.focusPointSupported ||
        size.isEmpty ||
        _busy) {
      return;
    }
    final point = Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    _focusIndicatorTimer?.cancel();
    setState(() => _focusPoint = point);
    try {
      await controller.setFocusPoint(point);
      _focusIndicatorTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    } on CameraException {
      if (mounted) {
        setState(() {
          _focusPoint = null;
          _error = '此设备暂不支持点按对焦';
        });
      }
    }
  }

  Widget _interactivePreview(CameraController controller, Widget preview) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final point = _focusPoint;
          return Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: '相机取景区',
                hint: controller.value.focusPointSupported
                    ? '点按预览对焦，双指调整倍率'
                    : '双指调整倍率',
                child: GestureDetector(
                  key: const Key('camera-preview-gestures'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _focusAt(details.localPosition, size),
                  onScaleStart: (_) => _gestureStartZoom = _zoom,
                  onScaleUpdate: (details) {
                    if (details.pointerCount > 1 && _maxZoom > _minZoom) {
                      unawaited(_setZoom(_gestureStartZoom * details.scale));
                    }
                  },
                  child: preview,
                ),
              ),
              if (point != null && controller.value.focusPointSupported)
                Positioned(
                  left: point.dx * size.width - 20,
                  top: point.dy * size.height - 20,
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const Key('camera-focus-indicator'),
                      size: const Size.square(48),
                      painter: _FocusRingPainter(color: AppColors.onMedia),
                    ),
                  ),
                ),
            ],
          );
        },
      );

  List<double> _zoomPresets() {
    if (_maxZoom <= _minZoom) return const [];
    final candidates = <double>[_minZoom, 1, 2, 3, _maxZoom];
    final result = <double>[];
    for (final candidate in candidates) {
      if (candidate < _minZoom || candidate > _maxZoom) continue;
      final value = candidate.clamp(_minZoom, _maxZoom).toDouble();
      if (result.every((item) => (item - value).abs() > .05)) {
        result.add(value);
      }
    }
    return result;
  }

  String _zoomLabel(double value) {
    final rounded = value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$rounded×';
  }

  Future<void> _openZoomFineTune() async {
    if (_busy || _maxZoom <= _minZoom || !mounted) return;
    var value = _zoom;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.spaceXl,
            0,
            AppLayout.spaceXl,
            AppLayout.spaceXxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '精细调整变焦',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(_zoomLabel(value)),
                ],
              ),
              Slider(
                key: const Key('camera-zoom-slider'),
                min: _minZoom,
                max: _maxZoom,
                value: value.clamp(_minZoom, _maxZoom).toDouble(),
                label: _zoomLabel(value),
                onChanged: _busy
                    ? null
                    : (next) {
                        setSheetState(() => value = next);
                        unawaited(_setZoom(next));
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cycleZoom() {
    final presets = _zoomPresets();
    if (presets.isEmpty || _busy) return;
    final currentIndex = presets.indexWhere(
      (value) => (_zoom - value).abs() < .05,
    );
    final next = presets[(currentIndex + 1) % presets.length];
    unawaited(_setZoom(next));
  }

  Widget _zoomDial({required bool onMedia}) {
    final presets = _zoomPresets();
    if (presets.isEmpty) return const SizedBox.shrink();
    return _XiaomiZoomDial(
      key: const Key('camera-zoom-dial'),
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      zoom: _zoom,
      presets: presets,
      onMedia: onMedia,
      enabled: !_busy,
      onChanged: (value) => unawaited(_setZoom(value)),
      onTap: _cycleZoom,
      onFineTune: _openZoomFineTune,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _focusIndicatorTimer?.cancel();
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Widget _mediaIconAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => Semantics(
    button: true,
    label: tooltip,
    child: SizedBox(
      width: AppLayout.touchTargetMin,
      height: AppLayout.touchTargetMin,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(
            AppLayout.touchTargetMin,
            AppLayout.touchTargetMin,
          ),
          foregroundColor: AppColors.onMedia,
          disabledForegroundColor: AppColors.onMedia.withValues(alpha: .42),
          backgroundColor: Colors.black.withValues(alpha: .28),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: AppLayout.iconMd),
      ),
    ),
  );

  Widget _mediaShutter(CameraController? controller) {
    final hasCapture = _capture != null;
    final enabled = !_busy && (hasCapture || controller != null);
    return Semantics(
      button: true,
      label: hasCapture ? '重试保存照片' : '拍照',
      child: SizedBox(
        width: 88,
        height: 88,
        child: Tooltip(
          message: hasCapture ? '重试保存照片' : '拍照',
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.onMedia, width: 4),
              color: Colors.transparent,
            ),
            child: Center(
              child: IconButton(
                key: const Key('evidence-camera-shoot'),
                onPressed: enabled
                    ? hasCapture
                          ? _confirm
                          : _shoot
                    : null,
                style: IconButton.styleFrom(
                  fixedSize: const Size(68, 68),
                  backgroundColor: hasCapture
                      ? AppColors.primary
                      : Colors.transparent,
                  foregroundColor: hasCapture
                      ? AppColors.onPrimary
                      : AppColors.primary,
                  disabledBackgroundColor: AppColors.onMedia.withValues(
                    alpha: .5,
                  ),
                  disabledForegroundColor: AppColors.primary.withValues(
                    alpha: .55,
                  ),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                icon: hasCapture
                    ? const Icon(Icons.check_rounded, size: AppLayout.iconLg)
                    : const Icon(
                        Icons.circle,
                        color: AppColors.onPrimary,
                        size: 52,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    if (widget.fullScreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.mediaBackground),
          if (_capture != null)
            Image.memory(_capture!, fit: BoxFit.contain)
          else if (controller != null && controller.value.isInitialized)
            LayoutBuilder(
              builder: (context, box) {
                final size = controller.value.previewSize!;
                final portrait =
                    MediaQuery.orientationOf(context) == Orientation.portrait;
                return _interactivePreview(
                  controller,
                  ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: portrait ? size.height : size.width,
                        height: portrait ? size.width : size.height,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                );
              },
            )
          else if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppLayout.spaceXxl),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .52),
                    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onMedia),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: AppLayout.spaceSm,
                  left: AppLayout.spaceSm,
                  child: IconButton(
                    tooltip: '返回',
                    onPressed: _busy
                        ? null
                        : (widget.onBack ?? widget.onCancel),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(
                        AppLayout.touchTargetMin,
                        AppLayout.touchTargetMin,
                      ),
                      backgroundColor: Colors.black.withValues(alpha: .38),
                      foregroundColor: AppColors.onMedia,
                      disabledForegroundColor: AppColors.onMedia.withValues(
                        alpha: .4,
                      ),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .82),
                          ],
                          stops: const [.5, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppLayout.spaceXl,
                  right: AppLayout.spaceXl,
                  bottom: AppLayout.spaceMd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_capture == null && _maxZoom > _minZoom)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppLayout.spaceMd,
                          ),
                          child: _zoomDial(onMedia: true),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _mediaIconAction(
                            tooltip: '选择图片',
                            icon: Icons.photo_library_outlined,
                            onPressed: _busy ? null : widget.onChooseFile,
                          ),
                          _mediaShutter(controller),
                          _mediaIconAction(
                            tooltip: _capture == null ? '不记录图片' : '重拍',
                            icon: _capture == null
                                ? Icons.close_rounded
                                : Icons.refresh_rounded,
                            onPressed: _busy
                                ? null
                                : _capture == null
                                ? widget.onCancel
                                : _retake,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (controller == null && _capture == null && !_busy)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 148,
                    child: Center(
                      child: TextButton(
                        onPressed: _start,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onMedia,
                          backgroundColor: Colors.black.withValues(alpha: .38),
                        ),
                        child: const Text('重试相机'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Container(
      key: const Key('evidence-camera-panel'),
      padding: const EdgeInsets.all(AppLayout.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusXl),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('为「${widget.title}」拍照', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppLayout.spaceSm),
          const Text('照片确认后加入当前草稿，保存后生效。'),
          const SizedBox(height: AppLayout.spaceMd),
          if (_capture != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                child: Image.memory(_capture!, fit: BoxFit.cover),
              ),
            )
          else if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                child: _interactivePreview(
                  controller,
                  CameraPreview(controller),
                ),
              ),
            )
          else if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            const SizedBox(height: AppLayout.spaceSm),
            Text(_error!, style: TextStyle(color: AppColors.error)),
          ],
          if (_capture == null && controller != null && _maxZoom > _minZoom)
            _zoomDial(onMedia: false),
          const SizedBox(height: AppLayout.spaceMd),
          Wrap(
            spacing: AppLayout.spaceSm,
            runSpacing: AppLayout.spaceSm,
            children: [
              if (_capture == null && controller != null)
                FilledButton.icon(
                  key: const Key('evidence-camera-shoot'),
                  onPressed: _busy ? null : _shoot,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.onPrimary,
                  ),
                  label: const Text('拍照'),
                ),
              if (_capture != null) ...[
                FilledButton(
                  key: const Key('evidence-camera-confirm'),
                  onPressed: _busy ? null : _confirm,
                  child: const Text('使用这张照片'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _retake,
                  child: const Text('重拍'),
                ),
              ],
              if (controller == null && !_busy)
                TextButton(onPressed: _start, child: const Text('重试相机')),
              TextButton(
                onPressed: _busy ? null : widget.onChooseFile,
                child: const Text('改选图片文件'),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: const Text('取消拍照'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint);
    const corner = 8.0;
    final left = center.dx - radius;
    final right = center.dx + radius;
    final top = center.dy - radius;
    final bottom = center.dy + radius;
    for (final segment in <(Offset, Offset)>[
      (Offset(left, top + corner), Offset(left, top)),
      (Offset(left, top), Offset(left + corner, top)),
      (Offset(right - corner, top), Offset(right, top)),
      (Offset(right, top), Offset(right, top + corner)),
      (Offset(left, bottom - corner), Offset(left, bottom)),
      (Offset(left, bottom), Offset(left + corner, bottom)),
      (Offset(right - corner, bottom), Offset(right, bottom)),
      (Offset(right, bottom), Offset(right, bottom - corner)),
    ]) {
      canvas.drawLine(segment.$1, segment.$2, paint);
    }
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _XiaomiZoomDial extends StatelessWidget {
  const _XiaomiZoomDial({
    super.key,
    required this.minZoom,
    required this.maxZoom,
    required this.zoom,
    required this.presets,
    required this.onMedia,
    required this.enabled,
    required this.onChanged,
    required this.onTap,
    required this.onFineTune,
  });

  final double minZoom;
  final double maxZoom;
  final double zoom;
  final List<double> presets;
  final bool onMedia;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onTap;
  final VoidCallback onFineTune;

  @override
  Widget build(BuildContext context) {
    final foreground = onMedia
        ? AppColors.onMedia
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final line = onMedia
        ? Colors.white.withValues(alpha: .58)
        : AppColors.outline.withValues(alpha: .7);
    return Semantics(
      button: true,
      label: '透明线条变焦轮盘，当前 ${_label(zoom)}',
      hint: '左右拖动连续变焦，轻触切换倍率，长按精细调整',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onFineTune : null,
        onHorizontalDragUpdate: enabled
            ? (details) {
                final sensitivity = (maxZoom - minZoom) / 260;
                onChanged(
                  (zoom + details.delta.dx * sensitivity)
                      .clamp(minZoom, maxZoom)
                      .toDouble(),
                );
              }
            : null,
        child: SizedBox(
          width: 292,
          height: 92,
          child: CustomPaint(
            painter: _ZoomDialPainter(
              minZoom: minZoom,
              maxZoom: maxZoom,
              zoom: zoom,
              presets: presets,
              lineColor: line,
              selectedColor: foreground,
            ),
          ),
        ),
      ),
    );
  }

  String _label(double value) {
    final text = value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text×';
  }
}

class _ZoomDialPainter extends CustomPainter {
  const _ZoomDialPainter({
    required this.minZoom,
    required this.maxZoom,
    required this.zoom,
    required this.presets,
    required this.lineColor,
    required this.selectedColor,
  });

  final double minZoom;
  final double maxZoom;
  final double zoom;
  final List<double> presets;
  final Color lineColor;
  final Color selectedColor;

  static const _startAngle = math.pi * 1.15;
  static const _sweepAngle = math.pi * .7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 22);
    final radius = size.width * .43;
    final arc = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(arc, _startAngle, _sweepAngle, false, base);

    final tickCount = 19;
    for (var index = 0; index < tickCount; index++) {
      final progress = index / (tickCount - 1);
      final angle = _startAngle + _sweepAngle * progress;
      final major = index % 3 == 0;
      final outer = _point(center, radius, angle);
      final inner = _point(center, radius - (major ? 13 : 8), angle);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = major ? selectedColor : lineColor
          ..strokeWidth = major ? 1.6 : 1,
      );
    }

    for (final preset in presets) {
      final progress = ((preset - minZoom) / (maxZoom - minZoom)).clamp(
        0.0,
        1.0,
      );
      final angle = _startAngle + _sweepAngle * progress;
      final point = _point(center, radius - 28, angle);
      final selected = (zoom - preset).abs() < .05;
      final painter = TextPainter(
        text: TextSpan(
          text: _label(preset),
          style:
              (selected
                      ? AppTypography.zoomTickSelected
                      : AppTypography.zoomTick)
                  .copyWith(color: selected ? selectedColor : lineColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        point - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final selectedProgress = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(
      0.0,
      1.0,
    );
    final selectedPoint = _point(
      center,
      radius - 14,
      _startAngle + _sweepAngle * selectedProgress,
    );
    canvas.drawCircle(selectedPoint, 4, Paint()..color = selectedColor);
    final current = TextPainter(
      text: TextSpan(
        text: _label(zoom),
        style: AppTypography.zoomValue.copyWith(color: selectedColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    current.paint(
      canvas,
      Offset(
        size.width / 2 - current.width / 2,
        size.height - current.height - 1,
      ),
    );
  }

  Offset _point(Offset center, double radius, double angle) => Offset(
    center.dx + math.cos(angle) * radius,
    center.dy + math.sin(angle) * radius,
  );

  String _label(double value) {
    final text = value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text×';
  }

  @override
  bool shouldRepaint(covariant _ZoomDialPainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.selectedColor != selectedColor ||
      oldDelegate.presets != presets;
}
