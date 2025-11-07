import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  static AudioPlayerService? _instance;
  AudioPlayer? _player;
  
  // Private constructor
  AudioPlayerService._();
  
  // Singleton getter dengan auto-cleanup
  static AudioPlayerService get instance {
    // Jika instance sudah ada, dispose dulu sebelum buat baru
    if (_instance != null && _instance!._player != null) {
      debugPrint("🔄 Disposing old AudioPlayer instance");
      _instance!._player!.dispose();
      _instance!._player = null;
    }
    
    _instance ??= AudioPlayerService._();
    return _instance!;
  }
  
  AudioPlayer get player {
    if (_player == null) {
      debugPrint("🎵 Creating new AudioPlayer instance");
      _player = AudioPlayer();
      _player!.setReleaseMode(ReleaseMode.release);
    }
    return _player!;
  }
  
  Future<void> reset() async {
    if (_player != null) {
      debugPrint("🛑 Resetting AudioPlayer");
      await _player!.stop();
      await _player!.release();
      await _player!.dispose();
      _player = null;
    }
  }
  
  // Method untuk force reset (dipanggil saat hot restart)
  static Future<void> forceReset() async {
    if (_instance?._player != null) {
      debugPrint("💥 Force resetting AudioPlayer");
      try {
        await _instance!._player!.stop();
        await _instance!._player!.release();
        await _instance!._player!.dispose();
      } catch (e) {
        debugPrint("Error during force reset: $e");
      }
      _instance!._player = null;
    }
    _instance = null;
  }
}