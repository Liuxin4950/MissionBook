import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_layout.dart';
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
              GestureDetector(
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
              if (point != null && controller.value.focusPointSupported)
                Positioned(
                  left: point.dx * size.width - 20,
                  top: point.dy * size.height - 20,
                  child: IgnorePointer(
                    child: Container(
                      key: const Key('camera-focus-indicator'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.onMedia, width: 2),
                        borderRadius: BorderRadius.circular(AppLayout.radiusSm),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Widget _zoomControl({required bool onMedia}) {
    if (_maxZoom <= _minZoom) return const SizedBox.shrink();
    final foreground = onMedia
        ? AppColors.onMedia
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.zoom_out, color: foreground, size: AppLayout.iconSm),
        Expanded(
          child: Slider(
            key: const Key('camera-zoom-slider'),
            min: _minZoom,
            max: _maxZoom,
            value: _zoom.clamp(_minZoom, _maxZoom).toDouble(),
            label: '${_zoom.toStringAsFixed(1)}×',
            onChanged: _busy ? null : (value) => unawaited(_setZoom(value)),
          ),
        ),
        Icon(Icons.zoom_in, color: foreground, size: AppLayout.iconSm),
        SizedBox(
          width: 42,
          child: Text(
            '${_zoom.toStringAsFixed(1)}×',
            textAlign: TextAlign.end,
            style: TextStyle(color: foreground),
          ),
        ),
      ],
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
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.onMedia),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: AppLayout.spaceSm,
                  left: AppLayout.spaceSm,
                  child: IconButton.filledTonal(
                    tooltip: '返回',
                    onPressed: _busy
                        ? null
                        : (widget.onBack ?? widget.onCancel),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                if (_capture == null && _maxZoom > _minZoom)
                  Positioned(
                    left: AppLayout.spaceLg,
                    right: AppLayout.spaceLg,
                    bottom: 92,
                    child: _zoomControl(onMedia: true),
                  ),
                if (_capture != null)
                  Positioned(
                    top: AppLayout.spaceSm,
                    right: AppLayout.spaceSm,
                    child: IconButton.filledTonal(
                      tooltip: '重拍',
                      onPressed: _busy ? null : _retake,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                Positioned(
                  left: AppLayout.spaceLg,
                  right: AppLayout.spaceLg,
                  bottom: AppLayout.spaceXl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : widget.onChooseFile,
                        child: const Text(
                          '选择图片',
                          style: TextStyle(color: AppColors.onMedia),
                        ),
                      ),
                      IconButton.filled(
                        key: const Key('evidence-camera-shoot'),
                        tooltip: _capture == null ? '拍照' : '重试保存照片',
                        iconSize: AppLayout.iconXl,
                        padding: const EdgeInsets.all(AppLayout.spaceLg),
                        onPressed: _busy
                            ? null
                            : _capture != null
                            ? _confirm
                            : controller == null
                            ? null
                            : _shoot,
                        icon: Icon(
                          _capture == null ? Icons.camera_alt : Icons.check,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      TextButton(
                        key: const Key('camera-text-only'),
                        onPressed: _busy ? null : widget.onCancel,
                        child: const Text(
                          '不记录图片',
                          style: TextStyle(color: AppColors.onMedia),
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller == null && _capture == null && !_busy)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: TextButton(
                        onPressed: _start,
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
            _zoomControl(onMedia: false),
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
