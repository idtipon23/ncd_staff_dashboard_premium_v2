// lib/core/utils/sound_util.dart
import 'sound_util_stub.dart'
    if (dart.library.js) 'sound_util_web.dart';

class SoundUtil {
  static void playUrgentBeep() {
    SoundPlatformUtil.playUrgentBeep();
  }
}