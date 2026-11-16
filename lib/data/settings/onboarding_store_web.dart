import 'package:web/web.dart' as web;

import '../../application/settings/onboarding_store.dart';

OnboardingStore createOnboardingStore() => _WebOnboardingStore();

class _WebOnboardingStore implements OnboardingStore {
  static const _key = 'mission_book.onboarding_v1';

  @override
  Future<bool> readCompleted() async =>
      web.window.localStorage.getItem(_key) == 'completed';

  @override
  Future<void> markCompleted() async {
    web.window.localStorage.setItem(_key, 'completed');
  }
}
