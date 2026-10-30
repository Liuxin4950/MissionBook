import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/app_layout.dart';

/// Android 材料草稿区内直接取景、重拍与确认，失败时保留原草稿。
class EvidenceCameraPanel extends StatefulWidget {
  const EvidenceCameraPanel({
    super.key,
    required this.missionTitle,
    required this.onConfirmed,
    required this.onChooseFile,
    required this.onCancel,
    this.fullScreen = false,
    this.onBack,
  });

  final String missionTitle;
  final Future<void> Function(Uint8List bytes, DateTime capturedAt) onConfirmed;
  final VoidCallback onChooseFile;
  final VoidCallback onCancel;
  final bool fullScreen;
  final VoidCallback? onBack;

  @override
  State<EvidenceCameraPanel> createState() => _EvidenceCameraPanelState();
}

class _EvidenceCameraPanelState extends State<EvidenceCameraPanel>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Uint8List? _capture;
  DateTime? _capturedAt;
  String? _error;
  bool _busy = false;
  int _generation = 0;

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
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      setState(() => _controller = next);
    } on CameraException catch (error) {
      await next?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = error.code == 'CameraAccessDenied'
              ? '相机权限未授予。可在系统设置中授权，或直接选择图片文件。'
              : '相机无法启动：${error.description ?? error.code}',
        );
      }
    } catch (error) {
      await next?.dispose();
      if (mounted && generation == _generation) {
        setState(() => _error = '相机无法启动：$error');
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
      _busy = false; // 授权弹窗也会短暂离开前台，返回后必须能重新取景。
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
      if (mounted) {
        setState(() {
          _capture = bytes;
          _capturedAt = DateTime.now().toUtc();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '拍照失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && widget.fullScreen && _capture != null) await _confirm();
  }

  Future<void> _confirm() async {
    final bytes = _capture;
    final capturedAt = _capturedAt;
    if (_busy || bytes == null || capturedAt == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirmed(bytes, capturedAt);
    } catch (error) {
      if (mounted) setState(() => _error = '照片加入草稿失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
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
          const ColoredBox(color: Colors.black),
          if (controller != null && controller.value.isInitialized)
            LayoutBuilder(
              builder: (context, box) {
                final size = controller.value.previewSize!;
                final portrait =
                    MediaQuery.orientationOf(context) == Orientation.portrait;
                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: portrait ? size.height : size.width,
                      height: portrait ? size.width : size.height,
                      child: CameraPreview(controller),
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
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton.filledTonal(
                    tooltip: '返回',
                    onPressed: _busy
                        ? null
                        : (widget.onBack ?? widget.onCancel),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : widget.onChooseFile,
                        child: const Text(
                          '选择图片',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton.filled(
                        key: const Key('evidence-camera-shoot'),
                        tooltip: '拍照',
                        iconSize: 44,
                        padding: const EdgeInsets.all(16),
                        onPressed: _busy || controller == null ? null : _shoot,
                        icon: const Icon(Icons.camera_alt),
                      ),
                      TextButton(
                        key: const Key('camera-text-only'),
                        onPressed: _busy ? null : widget.onCancel,
                        child: const Text(
                          '不记录图片',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller == null && !_busy)
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
          Text(
            '为「${widget.missionTitle}」拍照',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppLayout.spaceSm),
          const Text('照片确认后加入当前草稿，提交材料前不会成为正式记录。'),
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
                child: CameraPreview(controller),
              ),
            )
          else if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            const SizedBox(height: AppLayout.spaceSm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppLayout.spaceMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_capture == null && controller != null)
                FilledButton.icon(
                  key: const Key('evidence-camera-shoot'),
                  onPressed: _busy ? null : _shoot,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照'),
                ),
              if (_capture != null) ...[
                FilledButton(
                  key: const Key('evidence-camera-confirm'),
                  onPressed: _busy ? null : _confirm,
                  child: const Text('使用这张照片'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _capture = null),
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
