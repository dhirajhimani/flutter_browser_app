import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/translation_service.dart';

class TranslationPage extends StatefulWidget {
  final InAppWebViewController webViewController;

  const TranslationPage({
    super.key,
    required this.webViewController,
  });

  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final TranslationService _translationService = TranslationService();
  final List<TranslationPair> _translationPairs = [];

  bool _isInitializing = true;
  bool _isExtracting = false;
  bool _isTranslating = false;
  bool _isComplete = false;
  String _currentStatus = "Initializing...";
  double _progress = 0.0;

  List<String> _originalLines = [];
  int _currentTranslationIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTranslation();
  }

  Future<void> _startTranslation() async {
    try {
      // Step 1: Initialize translator
      setState(() {
        _currentStatus = "Initializing translator...";
        _progress = 0.1;
      });

      await _translationService.initializeTranslator();

      // Step 2: Check and download model if needed
      setState(() {
        _currentStatus = "Checking translation model...";
        _progress = 0.2;
      });

      final isModelDownloaded = await _translationService.isModelDownloaded();
      if (!isModelDownloaded) {
        setState(() {
          _currentStatus = "Downloading German translation model...";
          _progress = 0.3;
        });

        final downloaded = await _translationService.downloadModel();
        if (!downloaded) {
          setState(() {
            _currentStatus = "Failed to download translation model";
            _isInitializing = false;
          });
          return;
        }
      }

      // Step 3: Extract content
      setState(() {
        _currentStatus = "Extracting page content...";
        _progress = 0.4;
        _isInitializing = false;
        _isExtracting = true;
      });

      await _extractContent();

      // Step 4: Start translating
      setState(() {
        _currentStatus = "Starting translation...";
        _progress = 0.5;
        _isExtracting = false;
        _isTranslating = true;
      });

      await _translateContent();
    } catch (e) {
      setState(() {
        _currentStatus = "Error: ${e.toString()}";
        _isInitializing = false;
        _isExtracting = false;
        _isTranslating = false;
      });
    }
  }

  Future<void> _extractContent() async {
    final extractedContent =
        await widget.webViewController.evaluateJavascript(source: '''
      (function() {
        // Find main content areas
        var mainContentSelectors = [
          'main', 'article', '[role="main"]', '.main-content', '.content', '.post-content',
          '.article-content', '.entry-content', '.blog-content', '.page-content'
        ];
        
        var mainContainer = null;
        for (var selector of mainContentSelectors) {
          var element = document.querySelector(selector);
          if (element) {
            mainContainer = element;
            break;
          }
        }
        
        // If no main container found, use body but exclude non-content areas
        if (!mainContainer) {
          mainContainer = document.body;
        }
        
        var contentParts = [];
        var title = document.title || '';
        
        if (title.trim()) {
          contentParts.push('TITLE: ' + title.trim());
        }
        
        // Extract meaningful text content
        if (mainContainer) {
          var elements = mainContainer.querySelectorAll('h1, h2, h3, h4, h5, h6, p, blockquote, li');
          
          elements.forEach(function(element) {
            // Skip if element is in navigation, header, footer, etc.
            var skipElement = false;
            var parent = element;
            
            while (parent && parent !== document.body) {
              var classList = parent.className ? parent.className.toLowerCase() : '';
              var id = parent.id ? parent.id.toLowerCase() : '';
              
              if (classList.includes('nav') || classList.includes('menu') || 
                  classList.includes('header') || classList.includes('footer') ||
                  classList.includes('sidebar') || classList.includes('widget') ||
                  classList.includes('advertisement') || classList.includes('ad') ||
                  id.includes('nav') || id.includes('menu') || 
                  id.includes('header') || id.includes('footer') ||
                  parent.tagName === 'NAV' || parent.tagName === 'HEADER' || 
                  parent.tagName === 'FOOTER' || parent.tagName === 'ASIDE') {
                skipElement = true;
                break;
              }
              parent = parent.parentElement;
            }
            
            if (!skipElement) {
              var text = element.textContent.trim();
              if (text.length > 5 && text.length < 1000) {
                var prefix = '';
                if (element.tagName.startsWith('H')) {
                  prefix = 'HEADING: ';
                } else if (element.tagName === 'BLOCKQUOTE') {
                  prefix = 'QUOTE: ';
                } else if (element.tagName === 'LI') {
                  prefix = '• ';
                }
                contentParts.push(prefix + text);
              }
            }
          });
        }
        
        return contentParts.join('\\n\\n');
      })();
    ''');

    if (extractedContent == null ||
        extractedContent.toString().trim().isEmpty) {
      throw Exception("No content found to translate");
    }

    final content = extractedContent.toString();
    _originalLines =
        content.split('\n\n').where((line) => line.trim().isNotEmpty).toList();

    setState(() {
      _currentStatus = "Found ${_originalLines.length} sections to translate";
    });
  }

  Future<void> _translateContent() async {
    for (int i = 0; i < _originalLines.length; i++) {
      final originalLine = _originalLines[i].trim();
      if (originalLine.isEmpty) continue;

      setState(() {
        _currentTranslationIndex = i;
        _currentStatus =
            "Translating section ${i + 1} of ${_originalLines.length}";
        _progress = 0.5 + (0.5 * (i / _originalLines.length));
      });

      // Translate the line
      final translatedLine =
          await _translationService.translateText(originalLine);

      // Add to results immediately
      setState(() {
        _translationPairs.add(TranslationPair(
          english: _formatContent(originalLine),
          german: _formatContent(translatedLine ?? originalLine),
        ));
      });

      // Small delay between translations to prevent overwhelming the service
      if (i < _originalLines.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    setState(() {
      _isTranslating = false;
      _isComplete = true;
      _currentStatus = "Translation complete!";
      _progress = 1.0;
    });
  }

  String _formatContent(String content) {
    return content
        .replaceAll('TITLE: ', '')
        .replaceAll('HEADING: ', '')
        .replaceAll('QUOTE: ', '')
        .replaceAll('• ', '• ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Page Translation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isComplete ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isComplete ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status text
                Row(
                  children: [
                    if (!_isComplete) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _currentStatus,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content section
          Expanded(
            child: _translationPairs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.translate,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isInitializing
                              ? 'Preparing translation...'
                              : _isExtracting
                                  ? 'Extracting content...'
                                  : 'Starting translation...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _translationPairs.length,
                    itemBuilder: (context, index) {
                      final pair = _translationPairs[index];
                      return _buildTranslationPair(
                        english: pair.english,
                        german: pair.german,
                        isCurrentlyTranslating: _isTranslating &&
                            index == _translationPairs.length - 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationPair({
    required String english,
    required String german,
    bool isCurrentlyTranslating = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // English text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'EN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  english,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // German text (connected to English)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    if (isCurrentlyTranslating) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  german,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Don't dispose the translation service as it might be used elsewhere
    super.dispose();
  }
}

class TranslationPair {
  final String english;
  final String german;

  TranslationPair({
    required this.english,
    required this.german,
  });
}
