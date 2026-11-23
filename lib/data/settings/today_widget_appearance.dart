import '../notifications/today_widget_bridge.dart';

/// Color mode for Android Launcher widgets, independent of the app theme.
enum TodayWidgetTheme { system, light, dark }

/// Text density preference applied on top of Android's font scale.
enum TodayWidgetTextSize { standard, large }

/// The last appearance confirmed by Android for all Today widgets.
class TodayWidgetAppearance {
  const TodayWidgetAppearance({required this.theme, required this.textSize});

  final TodayWidgetTheme theme;
  final TodayWidgetTextSize textSize;

  /// Reads the native preference; a missing response must not look like a saved default.
  static Future<TodayWidgetAppearance> load() async {
    final settings = await TodayWidgetBridge.channel
        .invokeMapMethod<String, String>('getAppearance');
    final theme = TodayWidgetTheme.values
        .where((value) => value.name == settings?['theme'])
        .firstOrNull;
    final textSize = TodayWidgetTextSize.values
        .where((value) => value.name == settings?['textSize'])
        .firstOrNull;
    if (theme == null || textSize == null) {
      throw const FormatException('Invalid Android widget appearance');
    }
    return TodayWidgetAppearance(theme: theme, textSize: textSize);
  }

  /// Saves both fields together and asks Android to redraw the existing widgets.
  Future<void> save() => TodayWidgetBridge.channel.invokeMethod<void>(
    'setAppearance',
    {'theme': theme.name, 'textSize': textSize.name},
  );
}
