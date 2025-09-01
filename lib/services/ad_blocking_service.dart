import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AdBlockingService {
  static final AdBlockingService _instance = AdBlockingService._internal();
  factory AdBlockingService() => _instance;
  AdBlockingService._internal();

  // Comprehensive ad and tracking URL patterns
  static const List<String> _adUrlFilters = [
    // Google Ads
    ".*doubleclick\\.net/.*",
    ".*googleadservices\\.com/.*",
    ".*googlesyndication\\.com/.*",
    ".*googletagmanager\\.com/.*",
    ".*googletagservices\\.com/.*",
    ".*google-analytics\\.com/.*",
    ".*googletag\\..*",

    // Facebook/Meta Ads
    ".*facebook\\.com/adnw/.*",
    ".*facebook\\.com/tr/.*",
    ".*connect\\.facebook\\.net/.*",
    ".*facebook\\.com/plugins/.*",

    // Amazon Ads
    ".*amazon-adsystem\\.com/.*",
    ".*amazonclix\\.com/.*",

    // Microsoft Ads
    ".*ads\\.microsoft\\.com/.*",
    ".*bing\\.com/api/.*",

    // Other major ad networks
    ".*admob\\.com/.*",
    ".*adsystem\\.com/.*",
    ".*adnxs\\.com/.*",
    ".*adsystem\\..*",
    ".*outbrain\\.com/.*",
    ".*taboola\\.com/.*",
    ".*criteo\\.com/.*",
    ".*amazon\\.com/gp/aw/cr/.*",

    // Analytics and tracking
    ".*hotjar\\.com/.*",
    ".*fullstory\\.com/.*",
    ".*mixpanel\\.com/.*",
    ".*segment\\.com/.*",
    ".*amplitude\\.com/.*",
    ".*mouseflow\\.com/.*",
    ".*crazyegg\\.com/.*",
    ".*optimizely\\.com/.*",

    // Social media tracking
    ".*twitter\\.com/i/jot/.*",
    ".*linkedin\\.com/px/.*",
    ".*pinterest\\.com/ct/.*",
    ".*instagram\\.com/logging/.*",

    // Generic ad patterns
    ".*ads\\d*\\.[a-z]+/.*",
    ".*[a-z]+ads\\.[a-z]+/.*",
    ".*analytics\\.[a-z]+/.*",
    ".*tracker\\.[a-z]+/.*",
    ".*tracking\\.[a-z]+/.*",
    ".*metrics\\.[a-z]+/.*",
    ".*telemetry\\.[a-z]+/.*",

    // Common ad file patterns
    ".*/ads/.*",
    ".*/advertisement/.*",
    ".*/advertising/.*",
    ".*/banner/.*",
    ".*/popup/.*",
    ".*/sponsored/.*",
    ".*/tracking/.*",
    ".*/analytics/.*",
    ".*/metrics/.*",
    ".*/beacon/.*",

    // Ad script patterns
    ".*adsense.*",
    ".*adserv.*",
    ".*advert.*",
    ".*sponsor.*",
    ".*promo.*",
    ".*popup.*",
    ".*overlay.*",
    ".*interstitial.*",
  ];

  // Additional tracking patterns
  static const List<String> _trackingUrlFilters = [
    ".*track\\..*",
    ".*pixel\\..*",
    ".*beacon\\..*",
    ".*collect\\..*",
    ".*event\\..*",
    ".*log\\..*",
    ".*stats\\..*",
    ".*counter\\..*",
    ".*impression\\..*",
    ".*click\\..*",
    ".*view\\..*",
    ".*conversion\\..*",
  ];

  // Popup and overlay patterns
  static const List<String> _popupUrlFilters = [
    ".*popup.*",
    ".*overlay.*",
    ".*modal.*",
    ".*lightbox.*",
    ".*interstitial.*",
    ".*takeover.*",
    ".*fullscreen.*",
    ".*expandable.*",
  ];

  /// Generate content blockers based on enabled settings
  static List<ContentBlocker> generateContentBlockers({
    required bool adBlockingEnabled,
    required bool trackingProtectionEnabled,
    required bool popupBlockingEnabled,
  }) {
    List<ContentBlocker> blockers = [];

    if (adBlockingEnabled) {
      // Block ad URLs
      blockers.addAll(_adUrlFilters.map((filter) {
        return ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: filter,
            resourceType: [
              ContentBlockerTriggerResourceType.DOCUMENT,
              ContentBlockerTriggerResourceType.IMAGE,
              ContentBlockerTriggerResourceType.SCRIPT,
              ContentBlockerTriggerResourceType.STYLE_SHEET,
            ],
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        );
      }));
    }

    if (trackingProtectionEnabled) {
      // Block tracking URLs
      blockers.addAll(_trackingUrlFilters.map((filter) {
        return ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: filter,
            resourceType: [
              ContentBlockerTriggerResourceType.SCRIPT,
              ContentBlockerTriggerResourceType.IMAGE,
            ],
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        );
      }));
    }

    if (popupBlockingEnabled) {
      // Block popup URLs
      blockers.addAll(_popupUrlFilters.map((filter) {
        return ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: filter,
            resourceType: [
              ContentBlockerTriggerResourceType.DOCUMENT,
              ContentBlockerTriggerResourceType.SCRIPT,
            ],
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          ),
        );
      }));
    }

    return blockers;
  }

  /// Generate CSS rules to hide ad elements
  static String generateAdBlockingCSS() {
    return '''
      /* Hide common ad containers */
      [id*="ad"], [class*="ad"], [id*="ads"], [class*="ads"],
      [id*="banner"], [class*="banner"], [id*="popup"], [class*="popup"],
      [id*="sponsor"], [class*="sponsor"], [id*="promo"], [class*="promo"],
      [class*="advertisement"], [id*="advertisement"],
      [class*="advertising"], [id*="advertising"] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        width: 0 !important;
        height: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
      }
      
      /* Hide overlay and modal ads */
      .overlay, .modal, .lightbox, .popup-overlay,
      .interstitial, .takeover, .fullscreen-ad {
        display: none !important;
      }
      
      /* Hide sticky/fixed ad elements */
      [style*="position: fixed"], [style*="position: sticky"] {
        z-index: -1 !important;
      }
      
      /* Block common ad iframes */
      iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
      iframe[src*="googleadservices"], iframe[src*="facebook.com/tr"],
      iframe[src*="amazon-adsystem"] {
        display: none !important;
      }
    ''';
  }

  /// JavaScript to inject for enhanced ad blocking
  static String generateAdBlockingJS() {
    return '''
      (function() {
        // Block common ad functions
        window.addEventListener = (function(originalAddEventListener) {
          return function(type, listener, options) {
            if (type === 'beforeunload' && typeof listener === 'function') {
              // Block some popup triggers
              return;
            }
            return originalAddEventListener.call(this, type, listener, options);
          };
        })(window.addEventListener);
        
        // Override window.open to prevent popups
        const originalOpen = window.open;
        window.open = function(url, name, specs) {
          console.log('Blocked popup attempt:', url);
          return null;
        };
        
        // Block alert dialogs from ads
        const originalAlert = window.alert;
        window.alert = function(message) {
          if (typeof message === 'string' && (
            message.includes('winner') || 
            message.includes('congratulations') ||
            message.includes('prize') ||
            message.includes('click here')
          )) {
            console.log('Blocked suspicious alert:', message);
            return;
          }
          return originalAlert.call(this, message);
        };
        
        // Remove ads periodically
        function removeAds() {
          const adSelectors = [
            '[id*="ad"]', '[class*="ad"]', '[id*="ads"]', '[class*="ads"]',
            '[id*="banner"]', '[class*="banner"]', '[id*="popup"]', '[class*="popup"]',
            '[id*="sponsor"]', '[class*="sponsor"]', '[class*="advertisement"]',
            'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]'
          ];
          
          adSelectors.forEach(selector => {
            try {
              const elements = document.querySelectorAll(selector);
              elements.forEach(el => {
                if (el && el.parentNode) {
                  el.style.display = 'none';
                  el.style.visibility = 'hidden';
                  el.style.opacity = '0';
                  el.style.width = '0';
                  el.style.height = '0';
                }
              });
            } catch (e) {
              // Ignore errors
            }
          });
        }
        
        // Run ad removal on page load and periodically
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', removeAds);
        } else {
          removeAds();
        }
        
        // Periodic cleanup
        setInterval(removeAds, 2000);
        
        // Observer for dynamically added content
        if (typeof MutationObserver !== 'undefined') {
          const observer = new MutationObserver(function(mutations) {
            let shouldRemoveAds = false;
            mutations.forEach(function(mutation) {
              if (mutation.addedNodes.length > 0) {
                shouldRemoveAds = true;
              }
            });
            if (shouldRemoveAds) {
              setTimeout(removeAds, 100);
            }
          });
          
          observer.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true
          });
        }
      })();
    ''';
  }
}
