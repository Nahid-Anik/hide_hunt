import 'dart:io';
import 'package:flutter/services.dart';

/// Android can prefer mobile data over a Wi-Fi network without internet.
/// Bind guest sockets to connected Wi-Fi for the duration of the room.
class NetworkRoute {
  static const _channel = MethodChannel('hide_hunt/local_network');
  static Future<void> useWifi() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('useWifi');
  }

  static Future<void> keepAwake() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('keepAwake');
  }

  static Future<void> release() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('release');
      } on PlatformException {
        /* A lost network is already unbound. */
      }
    }
  }
}
