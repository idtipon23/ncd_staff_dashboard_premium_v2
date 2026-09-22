// lib/core/utils/sound_util_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class SoundPlatformUtil {
  static void playUrgentBeep() {
    try {
      js.context.callMethod('eval', [r'''
        (function() {
          try {
            var AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtx) return;
            var ctx = new AudioCtx();
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();

            osc.type = 'sine';
            osc.frequency.value = 880;

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start();
            osc.stop(ctx.currentTime + 0.25);
          } catch(e) {}
        })()
      ''']);
    } catch (_) {}
  }
}