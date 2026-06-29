import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// Fires a light haptic tap for a key interaction (turn completion, a
/// confirmation choice, a chip tap), gated on [AiThemeExtension.enableHaptics].
///
/// No-op on the web and on desktop platforms, where the `HapticFeedback`
/// channel isn't backed by a tactile actuator — guarded by
/// [defaultTargetPlatform] so a host doesn't get spurious platform-channel
/// chatter.
void aiLightHaptic(AiThemeExtension theme) {
  if (!theme.enableHaptics || kIsWeb) return;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      unawaited(HapticFeedback.lightImpact());
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      break;
  }
}
