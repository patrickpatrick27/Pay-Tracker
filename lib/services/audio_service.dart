import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// General test function using your one available file
  Future<void> playTestSound() async {
    try {
      await _player.stop();
      // AssetSource automatically looks inside the 'assets' folder
      await _player.play(AssetSource('sounds/payroll.mp3'), volume: 0.6);
    } catch (e) {
      print("❌ Audio Playback Error: $e");
    }
  }

  // We can point our logic methods to the same file for now
  Future<void> playClick() => playTestSound();
  Future<void> playSuccess() => playTestSound();
  Future<void> playDelete() => playTestSound();
}