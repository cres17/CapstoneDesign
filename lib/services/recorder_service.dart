import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class RecorderService {
  FlutterSoundRecorder? _recorder;
  String? _recordedFilePath;

  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordedFilePath = '${dir.path}/call_record.aac';
    print('[RecorderService] startRecording: $_recordedFilePath');
    await _recorder!.startRecorder(
      toFile: _recordedFilePath,
      codec: Codec.aacADTS,
    );
  }

  Future<String?> stopRecording() async {
    print('[RecorderService] stopRecording 호출됨');
    await _recorder!.stopRecorder();
    print('[RecorderService] stopRecording 반환: $_recordedFilePath');
    return _recordedFilePath;
  }

  void dispose() {
    _recorder?.closeRecorder();
  }
}
