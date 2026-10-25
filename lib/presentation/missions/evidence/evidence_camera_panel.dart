import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Android 材料草稿区内直接取景、重拍与确认，失败时保留原草稿。
class EvidenceCameraPanel extends StatefulWidget {
  const EvidenceCameraPanel({
    super.key,
    required this.missionTitle,
    required this.onConfirmed,
    required this.onChooseFile,
    required this.onCancel,
  });

  final String missionTitle;
  final Future<void> Function(Uint8List bytes, DateTime capturedAt) onConfirmed;
  final VoidCallback onChooseFile;
  final VoidCallback onCancel;

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
    return Container(
      key: const Key('evidence-camera-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '为「${widget.missionTitle}」拍照',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text('照片确认后加入当前草稿，提交材料前不会成为正式记录。'),
          const SizedBox(height: 12),
          if (_capture != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_capture!, fit: BoxFit.cover),
              ),
            )
          else if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CameraPreview(controller),
              ),
            )
          else if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
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
