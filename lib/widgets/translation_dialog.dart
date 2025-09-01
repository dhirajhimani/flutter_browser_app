import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/translation_service.dart';

class TranslationDialog {
  static Future<void> show({
    required BuildContext context,
    required InAppWebViewController webViewController,
  }) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text("Extracting and translating content..."),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Initialize translation service
      final translationService = TranslationService();
      await translationService.initializeTranslator();

      // Check if model is downloaded, if not download it
      final isModelDownloaded = await translationService.isModelDownloaded();
      if (!isModelDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Downloading German translation model..."),
            duration: Duration(seconds: 3),
          ),
        );

        final downloaded = await translationService.downloadModel();
        if (!downloaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to download translation model"),
            ),
          );
          return;
        }
      }

      // Extract main content from the page
      final extractedContent =
          await webViewController.evaluateJavascript(source: '''
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No content found to translate")),
        );
        return;
      }

      final content = extractedContent.toString();

      // Split content into chunks for translation (MLKit has limits)
      final chunks = <String>[];
      final lines = content.split('\n\n');
      String currentChunk = '';

      for (String line in lines) {
        if (currentChunk.length + line.length + 2 > 800) {
          if (currentChunk.isNotEmpty) {
            chunks.add(currentChunk.trim());
            currentChunk = '';
          }
        }
        if (currentChunk.isNotEmpty) {
          currentChunk += '\n\n';
        }
        currentChunk += line;
      }

      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
      }

      // Translate all chunks
      final translatedChunks = <String>[];
      for (int i = 0; i < chunks.length; i++) {
        final translatedChunk =
            await translationService.translateText(chunks[i]);
        if (translatedChunk != null && translatedChunk.isNotEmpty) {
          translatedChunks.add(translatedChunk);
        } else {
          translatedChunks.add(chunks[i]); // Fallback to original
        }

        // Small delay between translations
        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      final translatedContent = translatedChunks.join('\n\n');

      // Show the translation dialog
      await _showTranslationResult(
        context: context,
        originalContent: content,
        translatedContent: translatedContent,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Content translated to German!"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Translation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Translation failed: ${e.toString()}")),
      );
    }
  }

  static Future<void> _showTranslationResult({
    required BuildContext context,
    required String originalContent,
    required String translatedContent,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Translation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // English Section
                        const Text(
                          'English',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            _formatContent(originalContent),
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // German Section
                        const Text(
                          'German',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            _formatContent(translatedContent),
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatContent(String content) {
    return content
        .replaceAll('TITLE: ', '')
        .replaceAll('HEADING: ', '')
        .replaceAll('QUOTE: ', '')
        .replaceAll('• ', '• ')
        .trim();
  }
}
