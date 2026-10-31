import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/missions/evidence/evidence_camera_panel.dart';

class _Camera extends CameraPlatform {
  bool denied = false;
  int created = 0;
  int disposed = 0;
  final errors = StreamController<CameraErrorEvent>.broadcast();
  Completer<XFile>? pending;
  final bytes = File(
    'assets/illustrations/focus-hourglass.png',
  ).readAsBytesSync();
  XFile get photo => XFile.fromData(bytes, mimeType: 'image/png');
  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (denied) throw CameraException('CameraAccessDenied', 'test-only');
    return [
      const CameraDescription(
        name: 'test',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => ++created;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      errors.stream.where((event) => event.cameraId == cameraId);
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox(key: Key('fake-camera-preview'));
  @override
  Future<XFile> takePicture(int cameraId) async =>
      pending == null ? photo : pending!.future;
  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
    errors.add(CameraErrorEvent(cameraId, 'closed'));
  }
}

void main() {
  late _Camera camera;
  late CameraPlatform previous;
  setUp(() {
    previous = CameraPlatform.instance;
    camera = _Camera();
    CameraPlatform.instance = camera;
  });
  tearDown(() async {
    CameraPlatform.instance = previous;
    await camera.errors.close();
  });
  Future<void> open(
    WidgetTester tester, {
    bool fullScreen = false,
    Future<void> Function(Uint8List, DateTime)? save,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: EvidenceCameraPanel(
            missionTitle: '相机测试',
            fullScreen: fullScreen,
            onConfirmed: save ?? (_, _) async {},
            onChooseFile: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(camera.disposed, camera.created);
    expect(tester.takeException(), isNull);
  }

  testWidgets('权限拒绝有可恢复说明，重试成功，退出释放相机', (tester) async {
    camera.denied = true;
    await open(tester);
    expect(find.textContaining('相机权限未授予'), findsOneWidget);
    expect(find.text('改选图片文件'), findsOneWidget);
    camera.denied = false;
    await tester.tap(find.text('重试相机'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
    await close(tester);
  });

  testWidgets('照片保存失败保留同一份照片，重试不重复拍照', (tester) async {
    var attempts = 0;
    final captured = <Uint8List>[];
    await open(
      tester,
      save: (bytes, at) async {
        expect(at.isUtc, isTrue);
        captured.add(bytes);
        if (++attempts == 1) throw StateError('test disk error');
      },
    );
    await tester.tap(find.byKey(const Key('evidence-camera-shoot')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('使用这张照片'));
    await tester.tap(find.text('使用这张照片'));
    await tester.pumpAndSettle();
    expect(find.textContaining('照片已保留'), findsOneWidget);
    await tester.tap(find.text('使用这张照片'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(identical(captured.first, captured.last), isTrue);
    await close(tester);
  });

  testWidgets('全屏自动加入失败后可重试保存和重拍', (tester) async {
    var attempts = 0;
    await open(
      tester,
      fullScreen: true,
      save: (_, _) async {
        if (++attempts == 1) throw StateError('test disk error');
      },
    );
    await tester.tap(find.byKey(const Key('evidence-camera-shoot')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('重试保存照片'), findsOneWidget);
    await tester.tap(find.byTooltip('重试保存照片'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await tester.tap(find.byTooltip('重拍'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('拍照'), findsOneWidget);
    await close(tester);
  });

  testWidgets('拍照中离开前台会忽略迟到照片，恢复后重新取景', (tester) async {
    var saves = 0;
    camera.pending = Completer<XFile>();
    await open(tester, fullScreen: true, save: (_, _) async => saves++);
    await tester.tap(find.byKey(const Key('evidence-camera-shoot')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    camera.pending!.complete(camera.photo);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
    await close(tester);
  });
}
