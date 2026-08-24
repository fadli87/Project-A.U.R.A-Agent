class EmojiParser {
  EmojiParser._();

  static const Map<String, String> _shortcodes = {
    ':rocket:': '🚀',
    ':sparkles:': '✨',
    ':zap:': '⚡',
    ':bulb:': '💡',
    ':target:': '🎯',
    ':chart:': '📊',
    ':shield:': '🛡️',
    ':pushpin:': '📌',
    ':arrow:': '➔',
    ':warning:': '⚠️',
    ':info:': 'ℹ️',
    ':check:': '✅',
    ':smile:': '😊',
    ':wink:': '😉',
    ':grin:': '😁',
    ':laughing:': '😆',
    ':happy:': '😀',
    ':wave:': '👋',
    ':robot:': '🤖',
    ':question:': '❓',
    ':idea:': '💡',
    ':book:': '📖',
    ':lock:': '🔒',
    ':key:': '🔑',
    ':star:': '⭐',
    ':fire:': '🔥',
    ':thumbsup:': '👍',
    ':thumbsdown:': '👎',
    ':heart:': '❤️',
    ':ok_hand:': '👌',
    ':clap:': '👏',
    ':party:': '🎉',
    ':gift:': '🎁',
    ':bell:': '🔔',
    ':calendar:': '📅',
    ':clipboard:': '📋',
    ':memo:': '📝',
    ':phone:': '📱',
    ':computer:': '💻',
    ':gear:': '⚙️',
    ':wrench:': '🔧',
    ':hammer:': '🔨',
    ':alert:': '🚨',
    ':lock_with_key:': '🔐',
    ':globe:': '🌐',
    ':magnifier:': '🔍',
    ':email:': '✉️',
    ':folder:': '📁',
    ':file:': '📄',
  };

  /// Translates shortcodes (e.g. :rocket:) in text to actual emojis.
  /// Also sanitizes any corrupted unicode replacement characters (U+FFFD).
  static String replaceShortcodes(String text) {
    var result = text;
    _shortcodes.forEach((shortcode, emoji) {
      result = result.replaceAll(shortcode, emoji);
    });

    // Remove any accidental JNI-corrupted replacement characters (diamonds with question mark)
    result = result.replaceAll('\uFFFD', '');
    return result;
  }
}
