import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  OnDeviceTranslator? _translator;
  bool _isModelDownloaded = false;
  bool _isModelDownloading = false;

  /// Initialize the translator for English to German
  Future<bool> initializeTranslator() async {
    try {
      // Create translator for English to German
      _translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.german,
      );

      // Check if the German model is downloaded
      final modelManager = OnDeviceTranslatorModelManager();
      _isModelDownloaded = await modelManager
          .isModelDownloaded(TranslateLanguage.german.bcpCode);

      return true;
    } catch (e) {
      print('Error initializing translator: $e');
      return false;
    }
  }

  /// Download the German translation model if not already downloaded
  Future<bool> downloadModel() async {
    try {
      if (_isModelDownloaded) {
        return true;
      }
      _isModelDownloading = true;
      final modelManager = OnDeviceTranslatorModelManager();
      await modelManager.downloadModel(TranslateLanguage.german.bcpCode);
      _isModelDownloaded = true;
      _isModelDownloading = false;
      return true;
    } catch (e) {
      print('Error downloading model: $e');
      return false;
    }
  }

  /// Check if the German model is downloaded
  Future<bool> isModelDownloaded() async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      _isModelDownloaded = await modelManager
          .isModelDownloaded(TranslateLanguage.german.bcpCode);
      return _isModelDownloaded;
    } catch (e) {
      print('Error checking model download status: $e');
      return false;
    }
  }

  /// Translate text from English to German
  Future<String?> translateText(String text) async {
    try {
      if (_translator == null) {
        final initialized = await initializeTranslator();
        if (!initialized) {
          return null;
        }
      }

      // Ensure model is downloaded
      if (!_isModelDownloaded) {
        final downloaded = await downloadModel();
        if (!downloaded) {
          return null;
        }
      }

      final translatedText = await _translator!.translateText(text);
      return translatedText;
    } catch (e) {
      print('Error translating text: $e');
      return null;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _translator?.close();
    _translator = null;
  }

  // /// Get download progress (returns a rough estimate)
  bool get isModelDownloading => _isModelDownloading;
}
