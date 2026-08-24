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
  // An allowlist `if` rather than an exhaustive switch: the OHOS Flutter fork
  // adds TargetPlatform.ohos, so an exhaustive switch can't compile on both
  // it and upstream Flutter at once.
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
    unawaited(HapticFeedback.lightImpact());
  }
}
