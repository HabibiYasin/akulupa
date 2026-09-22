/// Phase 2: implement using Android speech recognition with an explicit
/// availability check for the installed Indonesian offline language model.
abstract interface class SpeechService {
  Future<bool> get isAvailable;
  Stream<String> transcribe();
  Future<void> stop();
}
