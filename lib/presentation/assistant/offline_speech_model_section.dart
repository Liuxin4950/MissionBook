import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/speech/speech_model_store.dart';

/// 用户主动下载离线模型；离开这一区域会取消尚未完成的下载。
class OfflineSpeechModelSection extends StatefulWidget {
  const OfflineSpeechModelSection({super.key, this.store});

  final SpeechModelStore? store;

  @override
  State<OfflineSpeechModelSection> createState() =>
      _OfflineSpeechModelSectionState();
}

class _OfflineSpeechModelSectionState extends State<OfflineSpeechModelSection> {
  late final _store = widget.store ?? createSpeechModelStore();
  bool _checking = true;
  bool _installed = false;
  bool _downloading = false;
  bool _cancelling = false;
  int _received = 0;
  int _total = 0;
  String? _message;
  DateTime? _lastProgress;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final installed =
          _store.supported && await _store.findInstalled() != null;
      if (mounted) setState(() => _installed = installed);
    } catch (_) {
      if (mounted) setState(() => _message = '无法检查模型文件，请稍后重试。');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _cancelling = false;
      _message = null;
      _received = 0;
      _total = _store.downloadBytes;
      _lastProgress = null;
    });
    try {
      await _store.download(
        onProgress: (received, total) {
          if (!mounted) return;
          final now = DateTime.now();
          if (received != total &&
              _lastProgress != null &&
              now.difference(_lastProgress!).inMilliseconds < 150) {
            return;
          }
          _lastProgress = now;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      if (mounted) setState(() => _installed = true);
    } on SpeechModelDownloadCancelled {
      if (mounted) setState(() => _message = '下载已取消，可随时重新下载。');
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on TimeoutException {
      if (mounted) setState(() => _message = '下载超时，请检查网络后重试。');
    } catch (_) {
      if (mounted) {
        setState(() => _message = '下载失败，请检查网络与可用存储空间后重试。');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _store.cancelDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.supported) {
      return const Text('当前仅 Android 支持离线语音；Windows 和浏览器可使用文字或录音转写服务。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _checking
              ? '正在检查离线模型…'
              : _installed
              ? '离线模型已就绪 · 无网可用'
              : '离线模型未下载（可选）',
          key: const Key('offline-model-status'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'SenseVoice 中文识别，每次最长 30 秒，无需 API Key。模型约 230 MB，点击下载才会联网；建议使用 Wi-Fi。下载后语音只在本机处理。',
        ),
        if (_downloading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _total > 0 ? _received / _total : null,
          ),
          const SizedBox(height: 8),
          Text(
            _cancelling
                ? '正在取消下载…'
                : _received == _total && _total > 0
                ? '正在校验模型…'
                : '${(_received / 1048576).toStringAsFixed(1)} / ${(_total / 1048576).toStringAsFixed(1)} MB',
            key: const Key('offline-model-progress'),
          ),
          TextButton(
            key: const Key('offline-model-cancel'),
            onPressed: _cancelling
                ? null
                : () {
                    setState(() => _cancelling = true);
                    _store.cancelDownload();
                  },
            child: const Text('取消下载'),
          ),
        ] else if (!_checking && !_installed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('offline-model-download'),
            onPressed: _download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('下载离线模型（约 230 MB）'),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, key: const Key('offline-model-message')),
        ],
      ],
    );
  }
}
