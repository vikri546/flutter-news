// article_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart'; // Import untuk SystemUiOverlayStyle

import '../services/api_service.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import '../utils/auth_service.dart'; // Import AuthService
import '../services/audio_player_service.dart';
import 'login_screen.dart'; // Import LoginScreen

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final String heroTag;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  const ArticleDetailScreen({
    Key? key,
    required this.article,
    required this.heroTag,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

// BARU: Enum untuk ukuran font
enum FontSize { small, medium, big }

class _ArticleDetailScreenState extends State<ArticleDetailScreen>
    with TickerProviderStateMixin {
  final String _geminiApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
  final ApiService _apiService = ApiService();
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  final HistoryService _historyService = HistoryService();
  final AuthService _authService = AuthService();
  bool _isLoggedIn = false;

  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;

  AudioPlayerService get _audioService => AudioPlayerService.instance;
  AudioPlayer get _audioPlayer => _audioService.player;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _addToHistory();
    _scrollController = ScrollController();
    _isBookmarkedLocal = widget.isBookmarked;

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.decelerate));

    // PERBAIKAN: Setup listener dengan cleanup otomatis
    _setupAudioPlayerListener();

    _initializeFlutterTts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  // TAMBAHKAN method baru ini
  void _setupAudioPlayerListener() {
    // Remove listener lama jika ada (penting untuk hot restart)
    debugPrint("🎧 Setting up audio player listener");
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint("AudioPlayer state: $state");
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isLoading = false;
            _currentTtsMode = "";
          });
        }
      }
    });
  }

  // TAMBAHKAN method ini untuk hot restart
  @override
  void reassemble() {
    super.reassemble();
    debugPrint("🔥 Hot restart detected - resetting audio");
    
    // Force reset audio player
    AudioPlayerService.forceReset();
    
    // Reset state
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isLoading = false;
        _currentTtsMode = "";
      });
    }
    
    // Setup listener lagi
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _setupAudioPlayerListener();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🗑️ Disposing ArticleDetailScreen");
    
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    
    // GANTI dengan service reset
    _audioService.reset();
    
    super.dispose();
  }

  bool _isSpeaking = false;
  bool _isLoading = false;
  String _fullTextForSpeech = "";

  int _currentWordStart = -1;
  int _currentWordEnd = -1;
  final GlobalKey _richTextKey = GlobalKey();

  String _currentTtsMode = "";

  late bool _isBookmarkedLocal;

  // BARU: State untuk ukuran font
  FontSize _currentFontSize = FontSize.medium;
  final Map<FontSize, double> _fontSizeMap = {
    FontSize.small: 15.0,
    FontSize.medium: 18.0,
    FontSize.big: 21.0,
  };

  Future<void> _checkLoginStatus() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null && user['username'] != 'Guest';
      });
    }
  }

  Future<void> _addToHistory() async {
    try {
      await _historyService.addToHistory(widget.article);
      debugPrint('Article added to history: ${widget.article.title}');
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  // --- FUNGSI BARU UNTUK MEMETAKAN KODE BAHASA ---
  /// Memetakan kode bahasa ISO 639-1 (misal "id") ke locale BCP 47 (misal "id-ID")
  /// Ini memberikan petunjuk yang lebih baik untuk engine TTS.
  String _getTtsLocale(String? articleLanguage) {
    if (articleLanguage == null || articleLanguage.isEmpty) {
      return 'id-ID'; // Default ke Indonesia jika tidak ada info
    }

    final Map<String, String> commonLocales = {
      'id': 'id-ID', // Indonesia
      'en': 'en-US', // Inggris (US)
      'es': 'es-ES', // Spanyol (Spanyol)
      'fr': 'fr-FR', // Perancis (Perancis)
      'de': 'de-DE', // Jerman (Jerman)
      'ja': 'ja-JP', // Jepang
      'ko': 'ko-KR', // Korea
      'zh': 'zh-CN', // Mandarin (China)
      'ru': 'ru-RU', // Rusia
      'ar': 'ar-SA', // Arab (Saudi)
      'pt': 'pt-BR', // Portugis (Brazil)
      'it': 'it-IT', // Italia
      'nl': 'nl-NL', // Belanda
      'tr': 'tr-TR', // Turki
      'vi': 'vi-VN', // Vietnam
      'th': 'th-TH', // Thailand
      'hi': 'hi-IN', // Hindi
      'sv': 'sv-SE', // Swedia
      'pl': 'pl-PL', // Polandia
      'el': 'el-GR', // Yunani
    };

    // 1. Cek apakah kode bahasa (misal "en") ada di peta umum
    if (commonLocales.containsKey(articleLanguage)) {
      return commonLocales[articleLanguage]!;
    }

    // 2. Cek apakah kodenya sudah merupakan locale (misal "en-GB")
    if (articleLanguage.contains('-') || articleLanguage.contains('_')) {
      return articleLanguage;
    }

    // 3. Jika hanya 2 huruf (misal "uk" untuk Ukraina), coba gunakan itu secara langsung
    if (articleLanguage.length == 2) {
      return articleLanguage;
    }

    // 4. Fallback default
    return 'id-ID';
  }

  Future<void> _initializeFlutterTts() async {
    if (_isTtsInitialized) return;

    _flutterTts = FlutterTts();
    debugPrint("Initializing Flutter TTS...");

    try {
      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _currentWordStart = -1;
            _currentWordEnd = -1;
            _currentTtsMode = "";
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _currentWordStart = -1;
            _currentWordEnd = -1;
            _currentTtsMode = "";
          });
        }
      });

      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _currentWordStart = -1;
            _currentWordEnd = -1;
            _currentTtsMode = "";
          });
        }
      });

      _flutterTts.setProgressHandler(
          (String text, int start, int end, String word) {
        if (mounted && _currentTtsMode == "normal") {
          if (mounted) {
            setState(() {
              _currentWordStart = start;
              _currentWordEnd = end;
            });
          }
          _scrollTo(start);
        }
      });

      // --- PERUBAHAN LOGIKA BAHASA DIMULAI DI SINI ---
      // Logika lama yang di-hardcode (id-ID / en-US) dihapus
      // dan diganti dengan logika dinamis.

      // 1. Dapatkan kode bahasa dari artikel (misal: "en", "id", "ja")
      //    Saya berasumsi widget.article.language ada.
      /* KODE YANG DIHAPUS KARENA ERROR
      final String articleLanguageCode =
          (widget.article.language?.isNotEmpty == true)
              ? widget.article.language!
              : 'id'; // Default ke 'id' jika artikel tidak punya info bahasa

      // 2. Dapatkan locale TTS yang spesifik (misal: "ja-JP")
      final String targetLocale = _getTtsLocale(articleLanguageCode);
      debugPrint(
          "TTS: Mencoba bahasa artikel: $articleLanguageCode -> $targetLocale");

      // 3. Coba set bahasa spesifik (misal: "ja-JP")
      var langResult = await _flutterTts.setLanguage(targetLocale);

      // 4. Jika gagal (misal "ja-JP" tidak ada), coba kode dasarnya (misal: "ja")
      if (langResult != 1 && targetLocale.contains('-')) {
        final String baseLanguageCode = targetLocale.split('-').first;
        debugPrint("TTS: $targetLocale gagal. Mencoba kode dasar: $baseLanguageCode");
        langResult = await _flutterTts.setLanguage(baseLanguageCode);
      }

      // 5. Jika masih gagal, fallback ke en-US
      if (langResult != 1) {
        debugPrint(
            "TTS: Bahasa artikel ($targetLocale) tidak didukung di perangkat ini. Fallback ke en-US.");
        await _flutterTts.setLanguage("en-US");
      } else {
        debugPrint("TTS: Bahasa $targetLocale berhasil diset.");
      }
      */ // --- AKHIR KODE YANG DIHAPUS ---

      // --- KODE BARU (MENGEMBALIKAN KE LOGIKA AWAL YANG STABIL) ---
      var langResult = await _flutterTts.setLanguage("id-ID");
      if (langResult != 1) {
        debugPrint("TTS: Bahasa Indonesia tidak tersedia, mencoba en-US");
        await _flutterTts.setLanguage("en-US");
      } else {
        debugPrint("TTS: Bahasa Indonesia berhasil diset.");
      }
      // --- PERUBAHAN LOGIKA BAHASA SELESAI ---

      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      if (!kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          await _flutterTts.setSharedInstance(true);
        }
        if (Platform.isIOS) {
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          );
        }
      }

      _isTtsInitialized = true;
      debugPrint("Flutter TTS initialized successfully");
    } catch (e) {
      debugPrint("Error initializing Flutter TTS: $e");
      _isTtsInitialized = false;
    }
    if (mounted) setState(() {});
  }

  void _popWithResult(BuildContext context) {
    final result = {'isBookmarked': _isBookmarkedLocal};
    Navigator.pop(context, result);
  }

  void _showFocusedImage(BuildContext context, String? imageUrl, String heroTag,
      String title, String category) {
    if (imageUrl == null || imageUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      useSafeArea: false,
      builder: (BuildContext context) {
        return _FocusedImageView(
            imageUrl: imageUrl, heroTag: heroTag, title: title, category: category);
      },
    );
  }

  String _stripHtml(String htmlString) {
    final document = parse(htmlString);
    final String? text = document.body?.text;
    return text != null ? parse(text).documentElement!.text.trim() : '';
  }

  String _formatDateRelative(DateTime dateTime) {
    try {
      final Duration difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 7)
        return DateFormat('d MMM y', 'id_ID').format(dateTime);
      if (difference.inDays >= 1) return '${difference.inDays} hari lalu';
      if (difference.inHours >= 1) return '${difference.inHours} jam lalu';
      if (difference.inMinutes >= 1) return '${difference.inMinutes} mnt lalu';
      return 'Baru saja';
    } catch (e) {
      return DateFormat('d MMM y', 'id_ID').format(dateTime);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        _showErrorSnackBar('Tidak dapat membuka tautan:\n$urlString');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal membuka tautan:\n$urlString');
    }
  }

  Future<void> _showTtsModeSelection() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgGradientStart =
        isDark ? const Color(0xFF242443) : const Color(0xFFEDE7F6);
    final Color bgGradientEnd =
        isDark ? const Color(0xFF12121E) : const Color(0xFFFFFFFF);

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bgGradientStart, bgGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.55 : 0.18),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 30),
                      Text(
                        'Mode Baca',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: isDark ? Colors.white : Colors.indigo[900],
                          shadows: [
                            Shadow(
                              color: isDark
                                  ? Colors.black26
                                  : Colors.indigo.shade100,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pilih suara untuk membaca',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: isDark ? Colors.grey[300] : Colors.indigo[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildTtsModeOption(
                        context: context,
                        icon: Icons.record_voice_over,
                        description: 'Suara HP',
                        badge: 'GRATIS',
                        badgeColor: Colors.green.shade600,
                        iconColor: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(context);
                          _startNormalTts();
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTtsModeOption(
                        context: context,
                        icon: Icons.auto_awesome,
                        description: 'Suara AI',
                        badge: 'PREMIUM',
                        badgeColor: Colors.purple,
                        iconColor: Colors.deepPurple,
                        onTap: () {
                          Navigator.pop(context);
                          _startGeminiTts();
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: ButtonStyle(
                            foregroundColor: MaterialStateProperty.all(
                                isDark ? Colors.white : Colors.indigo[900]),
                            overlayColor: MaterialStateProperty.all(
                                (isDark ? Colors.white24 : Colors.indigo[50])),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.close_rounded, size: 19),
                              const SizedBox(width: 6),
                              Text("Batal",
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.purple.shade900, Colors.deepPurple.shade700]
                          : [Colors.indigo, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.purpleAccent.withOpacity(0.30)
                            : Colors.blue.withOpacity(0.13),
                        blurRadius: 22,
                        spreadRadius: 3,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.spatial_audio_rounded,
                    color: Colors.white,
                    size: 40,
                    shadows: [
                      Shadow(color: Colors.purple.withOpacity(0.18), blurRadius: 16)
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTtsModeOption({
    required BuildContext context,
    required IconData icon,
    required String description,
    required String badge,
    required Color badgeColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking || _isLoading) {
      await _stopSpeaking();
    } else {
      _fullTextForSpeech = _prepareTextForSpeech();
      await _showTtsModeSelection();
    }
  }

  Future<void> _startNormalTts() async {
    if (!_isTtsInitialized) {
      await _initializeFlutterTts();
      if (!_isTtsInitialized && mounted) {
        _showErrorSnackBar("Fitur Suara tidak tersedia saat ini.");
        return;
      }
    }

    setState(() {
      _currentTtsMode = "normal";
    });

    await _speakWithFlutterTts();
  }

  Future<void> _startGeminiTts() async {
    if (_geminiApiKey == "AIzaSyDa3Fo_obfSV_DTUo8OmaSUiR7U7KllYEs" || _geminiApiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      return;
    }

    setState(() {
      _currentTtsMode = "gemini";
      _isLoading = true;  
    });

    await _fetchAndPlayGeminiTts();
  }

  Future<void> _speakWithFlutterTts() async {
    if (_fullTextForSpeech.isEmpty) {
      _showErrorSnackBar("Tidak ada teks untuk dibacakan");
      return;
    }
    try {
      await _flutterTts.stop();
      var result = await _flutterTts.speak(_fullTextForSpeech);
      if (result != 1) {
        debugPrint("TTS failed to start with result: $result");
        if (mounted) setState(() => _isSpeaking = false);
        _showErrorSnackBar("Gagal memulai pembacaan teks");
      } else {
        debugPrint("TTS speak initiated successfully");
      }
    } catch (e) {
      debugPrint("Error speaking: $e");
      if (mounted) setState(() => _isSpeaking = false);
      _showErrorSnackBar("Gagal memutar audio");
    }
  }

  // GANTI SELURUH FUNGSI _fetchAndPlayGeminiTts DENGAN INI:
  Future<void> _fetchAndPlayGeminiTts() async {
    if (_fullTextForSpeech.isEmpty) {
      _showErrorSnackBar("Tidak ada teks untuk dibacakan");
      setState(() => _isLoading = false);
      return;
    }

    final String? apiKey = dotenv.env['GOOGLE_TTS_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      setState(() => _isLoading = false);
      return;
    }

    // Gunakan endpoint v1 (production-ready)
    final String apiUrl = "https://texttospeech.googleapis.com/v1/text:synthesize";

    // Untuk Gemini TTS, gunakan voice name dengan format: {languageCode}-{voiceType}-{variant}
    // Contoh: id-ID-Neural2-A, en-US-Neural2-C
    final payload = jsonEncode({
      "input": { "text": _fullTextForSpeech },
      "voice": {
        "languageCode": "id-ID",
        "name": "id-ID-Chirp3-HD-Leda"
      },
      "audioConfig": {
        "audioEncoding": "MP3"
      }
    }
    );
    // final payload = jsonEncode({
    //   "input": { "text": _fullTextForSpeech },
    //   "voice": {
    //     "languageCode": "id-ID",
    //     "name": "Leda",              // 🔑 gunakan nama voice dari Gemini TTS
    //     "modelName": "gemini-2.5-pro-tts" // atau "gemini-2.5-flash-tts"
    //   },
    //   "audioConfig": {
    //     "audioEncoding": "MP3",
    //     "speakingRate": 1.0,
    //     "pitch": 0.0
    //   }
    // });

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Mengirim request ke Cloud TTS API (Gemini)...");
      debugPrint("URL: $apiUrl?key=***");

      final response = await http
          .post(
            Uri.parse("$apiUrl?key=$apiKey"),
            headers: {
              'Content-Type': 'application/json',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 60));

      debugPrint("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final String? audioData = result['audioContent'];

        if (audioData != null) {
          debugPrint("Audio MP3 diterima, ukuran: ${audioData.length} bytes (base64)");
          
          final audioBytes = base64Decode(audioData);
          debugPrint("Audio decoded, ukuran: ${audioBytes.length} bytes");

          await _audioPlayer.play(BytesSource(audioBytes));

          if (mounted) {
            setState(() {
              _isLoading = false;
              _isSpeaking = true;
            });
          }
        } else {
          throw Exception("Tidak ada data audio dalam respons");
        }
      } else {
        debugPrint("Error ${response.statusCode}: ${response.body}");
        
        String errorMessage = "Error tidak diketahui";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.body;
        }
        
        throw Exception("HTTP ${response.statusCode}: $errorMessage");
      }
    } on TimeoutException {
      _showErrorSnackBar("Request timeout. Periksa koneksi internet Anda.");
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _isSpeaking = false; 
          _currentTtsMode = ""; 
        });
      }
    } catch (e) {
      debugPrint("Error fetching Cloud TTS: $e");
      _showErrorSnackBar("Gagal memuat audio: ${e.toString()}");
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _isSpeaking = false; 
          _currentTtsMode = ""; 
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      if (_currentTtsMode == "normal") {
        await _flutterTts.stop();
      } else if (_currentTtsMode == "gemini") {
        await _audioPlayer.stop();
      }

      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
          _currentWordStart = -1;
          _currentWordEnd = -1;
          _currentTtsMode = "";
        });
      }
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
          _currentWordStart = -1;
          _currentWordEnd = -1;
          _currentTtsMode = "";
        });
      }
    }
  }

  void _scrollTo(int startOffset) {
    final keyContext = _richTextKey.currentContext;
    if (keyContext == null) return;

    final RenderBox renderBox = keyContext.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final InlineSpan span = (_richTextKey.currentWidget as RichText).text;
    final TextPainter painter = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    painter.layout(maxWidth: size.width);

    final Offset wordOffset = painter.getOffsetForCaret(
      TextPosition(offset: startOffset),
      Rect.zero,
    );

    final double lineHeight = painter.preferredLineHeight;
    final Offset wordGlobalOffset = renderBox.localToGlobal(wordOffset);
    final double screenHeight = MediaQuery.of(context).size.height;

    final double topMargin = screenHeight * 0.2;
    final double bottomMargin = screenHeight * 0.8;

    if (wordGlobalOffset.dy < topMargin ||
        (wordGlobalOffset.dy + lineHeight) > bottomMargin) {
      double targetScrollOffset =
          _scrollController.offset + (wordGlobalOffset.dy - (screenHeight * 0.3));

      targetScrollOffset = targetScrollOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        targetScrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _prepareTextForSpeech() {
    StringBuffer buffer = StringBuffer();
    // Set default locale untuk pemformatan, tapi TTS akan menggunakan bahasanya sendiri
    Intl.defaultLocale = 'id_ID';

    buffer.writeln(widget.article.title);
    buffer.writeln();

    final String? authorString = widget.article.author?.replaceAll(' / ', ', ');
    final String? penulisString = widget.article.penulis;
    final bool hasAuthor = authorString != null &&
        authorString.isNotEmpty &&
        authorString != 'Unknown Author';
    final bool hasPenulis =
        penulisString != null && penulisString.isNotEmpty;

    if (hasAuthor) buffer.write("Author $authorString. ");
    if (hasAuthor && hasPenulis) buffer.write(" | ");
    if (hasPenulis) buffer.write("Penulis $penulisString. ");
    if (hasAuthor || hasPenulis) buffer.writeln();

    // -- PERUBAHAN: Jangan paksakan format tanggal 'WIB' jika artikel internasional --
    // Gunakan format yang lebih netral jika bahasa bukan 'id'
    /* KODE YANG DIHAPUS KARENA ERROR
    final bool isIndonesian = (widget.article.language ?? 'id') == 'id';
    
    final DateFormat updateDateFormat = isIndonesian
        ? DateFormat('MMMM d, yyyy, h:mm a', 'id_ID')
        : DateFormat('MMMM d, yyyy, h:mm a', 'en_US'); // Fallback ke format EN

    String updateString = "Update ${updateDateFormat.format(widget.article.modifiedAt)}";
    if (isIndonesian) updateString += " WIB";
    */ // --- AKHIR KODE YANG DIHAPUS ---

    // --- KODE BARU (MENGEMBALIKAN KE LOGIKA AWAL) ---
    final DateFormat updateDateFormat = DateFormat('MMMM d, yyyy, h:mm a');
    final String updateString =
        "Update ${updateDateFormat.format(widget.article.modifiedAt)} WIB";
    // --- AKHIR KODE BARU ---

    buffer.writeln(updateString);
    buffer.writeln();

    String? content = widget.article.content ?? widget.article.description;
    if (content != null && content.isNotEmpty) {
      String cleanContent = _stripHtml(content);
      
      // Hanya lakukan penggantian spesifik bahasa jika kita yakin ini bahasa Indonesia
      /* KODE YANG DIHAPUS KARENA ERROR
      if (isIndonesian) {
        cleanContent = cleanContent
            .replaceAll("dll.", "dan lain-lain")
            .replaceAll("dsb.", "dan sebagainya")
            .replaceAll("Yth.", "Yang terhormat");
      }
      buffer.write(cleanContent);
      */ // --- AKHIR KODE YANG DIHAPUS ---

      // --- KODE BARU (MENGEMBALIKAN KE LOGIKA AWAL) ---
      cleanContent = cleanContent
          .replaceAll("dll.", "dan lain-lain")
          .replaceAll("dsb.", "dan sebagainya")
          .replaceAll("Yth.", "Yang terhormat");
      buffer.write(cleanContent);
      // --- AKHIR KODE BARU ---
    } else {
      buffer.write("Konten tidak tersedia.");
    }

    return buffer.toString();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message))
        ]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
            label: 'TUTUP',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar())));
  }

  void _showBookmarkSnackbar(bool isBookmarked) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBookmarked ? 'Artikel disimpan ke bookmark' : 'Bookmark dihapus',
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _showLoginRequiredPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color customGreen = Color(0xFF39e011);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
              .copyWith(
            bottom: MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Buat akun untuk menyimpan artikel ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  ).then((_) => _checkLoginStatus());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: customGreen,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Lanjutkan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetailedErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  void _shareArticle() {
    final String title = widget.article.title;
    String description = _stripHtml(widget.article.description ?? "");
    if (description.isNotEmpty) {
      const int maxLength = 200;
      if (description.length > maxLength) {
        description = description.substring(0, maxLength) + "...";
      }
    } else {
      description = "Tidak ada deskripsi.";
    }
    final String author = (widget.article.author != null &&
            widget.article.author!.isNotEmpty &&
            widget.article.author != "Unknown Author")
        ? widget.article.author!
        : "Tidak diketahui";
    final String publishDate =
        DateFormat('d MMM y, HH:mm', 'id_ID').format(widget.article.publishedAt);
    final String tag = "#${widget.article.category.toLowerCase()}";
    final String link = widget.article.url;
    final String shareContent = """
  Judul: $title

  Deskripsi: $description

  Author: $author
  Tanggal: $publishDate
  Tag: $tag

  Baca selengkapnya disini:
  $link
  """;

    Share.share(shareContent, subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Intl.defaultLocale = 'id_ID';

    return WillPopScope(
      onWillPop: () async {
        if (_isSpeaking || _isLoading) await _stopSpeaking();
        _popWithResult(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          backgroundColor: isDark ? Colors.black : Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: isDark ? Colors.black : Colors.white,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) => FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(position: _slideAnimation, child: child)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.article.urlToImage != null)
                      GestureDetector(
                        onTap: () => _showFocusedImage(
                            context,
                            widget.article.urlToImage,
                            widget.heroTag,
                            widget.article.title,
                            widget.article.category),
                        child: Hero(
                          tag: widget.heroTag,
                          child: CachedNetworkImage(
                            imageUrl: widget.article.urlToImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 250,
                            placeholder: (c, u) => Container(
                                color: Colors.grey[300],
                                height: 250,
                                child: const Center(
                                    child: CircularProgressIndicator())),
                            errorWidget: (c, u, e) => Container(
                                color: Colors.grey[300],
                                height: 250,
                                child: const Center(
                                    child: Icon(Icons.image_not_supported,
                                        color: Colors.grey, size: 50))),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(23.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5FF10),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  widget.article.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateRelative(widget.article.publishedAt),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isSpeaking && _currentTtsMode == "normal")
                            _buildReadingView(context)
                          else
                            _buildStandardView(context),
                          if (widget.article.tags.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildTagsSection(context),
                            const SizedBox(height: 24),
                          ] else ...[
                            const SizedBox(height: 24),
                          ],
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () => _launchURL(widget.article.url),
                              icon: Icon(_getPlatformIcon(), size: 20),
                              label: Text(_getPlatformButtonText()),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_getPlatformInfoIcon(),
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  _getPlatformInfoText(),
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildMainBottomBar(context),
      ),
    );
  }

  Widget _buildMainBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 4.0, vertical: 4.0), // Padding disesuaikan
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kiri: Kembali dan Font
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    onPressed: () async {
                      if (_isSpeaking || _isLoading) await _stopSpeaking();
                      _popWithResult(context);
                    },
                    padding: const EdgeInsets.all(12),
                  ),
                  _buildFontMenuButton(), // BARU: Tombol menu font
                ],
              ),

              // Kanan: Dengar, Share, Bookmark
              Row(
                children: [
                  _buildTtsIconButton(), // BARU: Tombol icon TTS
                  Container(
                    height: 20,
                    width: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      color: isDark ? Colors.white : Colors.black,
                      size: 22,
                    ),
                    onPressed: _shareArticle,
                    padding: const EdgeInsets.all(12),
                  ),
                  Container(
                    height: 20,
                    width: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  BookmarkIconButton(
                    isBookmarked: _isBookmarkedLocal,
                    onToggle: () {
                      if (_isLoggedIn) {
                        widget.onBookmarkToggle();
                        final newBookmarkState = !_isBookmarkedLocal;
                        setState(() {
                          _isBookmarkedLocal = newBookmarkState;
                        });
                        _showBookmarkSnackbar(newBookmarkState);
                      } else {
                        _showLoginRequiredPanel();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontMenuButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final fadedColor =
        isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);

    String getLabel(FontSize size) {
      switch (size) {
        case FontSize.small:
          return "Small";
        case FontSize.medium:
          return "Medium";
        case FontSize.big:
          return "Large";
      }
    }

    IconData getSizeIcon(FontSize size) {
      switch (size) {
        case FontSize.small:
          return Icons.text_fields;
        case FontSize.medium:
          return Icons.text_increase;
        case FontSize.big:
          return Icons.format_size;
      }
    }

    // Jangan transparan ketika pilihan sudah terbuka
    return StatefulBuilder(
      builder: (context, setSB) {
        bool opened = false;
        return PopupMenuButton<FontSize>(
          onSelected: (FontSize newSize) {
            setState(() {
              _currentFontSize = newSize;
            });
            setSB(() {
              opened = false;
            });
          },
          onCanceled: () {
            setSB(() {
              opened = false;
            });
          },
          onOpened: () {
            setSB(() {
              opened = true;
            });
          },
          // Modifikasi di sini: background popup SELALU ADA bukan transparan
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            side: opened
                ? BorderSide(
                    color: isDark
                        ? (Theme.of(context).colorScheme.primary.withOpacity(0.16))
                        : (Theme.of(context).colorScheme.primary.withOpacity(0.21)),
                    width: 1.2)
                : BorderSide(
                    color: isDark
                        ? (Theme.of(context).colorScheme.primary.withOpacity(0.10))
                        : (Theme.of(context).colorScheme.primary.withOpacity(0.11)),
                    width: 1.0,
                  ),
          ),
          color: isDark ? Colors.grey[900]! : Colors.white,
          elevation: opened ? 8 : 4,
          itemBuilder: (BuildContext context) {
            return FontSize.values.map((size) {
              final selected = _currentFontSize == size;
              return PopupMenuItem<FontSize>(
                value: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.08))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 16,
                        child: Icon(
                          getSizeIcon(size),
                          size: 18 + FontSize.values.indexOf(size) * 2,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : fadedColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getLabel(size),
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : iconColor,
                                fontSize: 15.0 + FontSize.values.indexOf(size).toDouble(),
                              ),
                            ),
                            Text(
                              "${_fontSizeMap[size]?.toStringAsFixed(0)} px",
                              style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : fadedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary, size: 20)
                      ]
                    ],
                  ),
                ),
              );
            }).toList();
          },
          child: Container(
            decoration: BoxDecoration(
              color: opened
                  ? (isDark
                      ? Colors.grey[900]!
                      : Colors.grey[50])
                  : Colors.transparent,
              border: opened
                  ? Border.all(
                      color: isDark
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.16)
                          : Theme.of(context).colorScheme.primary.withOpacity(0.22),
                      width: 1.2)
                  : null,
              boxShadow: opened
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
              borderRadius: const BorderRadius.all(Radius.circular(100)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_fields_rounded, color: iconColor, size: 22),
                const SizedBox(width: 2),
                Text(
                  getLabel(_currentFontSize),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: fadedColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandardView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.article.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Domine',
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: 0.3,
            height: 1.3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _buildMetaInfoSection(context),
        const SizedBox(height: 24),
        ..._buildContentWithBlockquotes(widget.article.content),
      ],
    );
  }

  Widget _buildReadingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseTextStyle = TextStyle(
      fontFamily: 'SourceSerif4',
      fontWeight: FontWeight.w400,
      fontSize: _fontSizeMap[_currentFontSize]!, // PERUBAHAN: Terapkan font size
      height: 1.7,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    final highlightStyle = baseTextStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.7),
      color: Colors.black,
      fontWeight: FontWeight.w600,
    );

    List<TextSpan> spans = [];
    if (_fullTextForSpeech.isEmpty) {
      _fullTextForSpeech = _prepareTextForSpeech();
    }

    if (_currentWordStart == -1 || _currentWordEnd > _fullTextForSpeech.length) {
      spans.add(TextSpan(text: _fullTextForSpeech, style: baseTextStyle));
    } else {
      spans.add(TextSpan(
        text: _fullTextForSpeech.substring(0, _currentWordStart),
        style: baseTextStyle,
      ));
      spans.add(TextSpan(
        text: _fullTextForSpeech.substring(_currentWordStart, _currentWordEnd),
        style: highlightStyle,
      ));
      spans.add(TextSpan(
        text: _fullTextForSpeech.substring(_currentWordEnd),
        style: baseTextStyle,
      ));
    }

    return RichText(
      key: _richTextKey,
      textAlign: TextAlign.left,
      text: TextSpan(
        style: baseTextStyle,
        children: spans,
      ),
    );
  }

  Widget _buildMetaInfoSection(BuildContext context) {
    final String? authorString = widget.article.author?.replaceAll(' / ', ', ');
    final String? penulisString = widget.article.penulis;

    final bool hasAuthor = authorString != null &&
        authorString.isNotEmpty &&
        authorString != 'Unknown Author';
    final bool hasPenulis =
        penulisString != null && penulisString.isNotEmpty;

    final DateFormat updateDateFormat = DateFormat('MMMM d, yyyy, h:mm a');
    final String updateString =
        "Update ${updateDateFormat.format(widget.article.modifiedAt)} WIB";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasAuthor || hasPenulis)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                children: [
                  if (hasAuthor)
                    TextSpan(
                      children: [
                        const TextSpan(text: "Author by "),
                        TextSpan(
                          text: authorString,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  if (hasAuthor && hasPenulis)
                    const TextSpan(text: "   |   "),
                  if (hasPenulis)
                    TextSpan(
                      children: [
                        const TextSpan(text: "Penulis by "),
                        TextSpan(
                          text: penulisString,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (hasAuthor || hasPenulis) const SizedBox(height: 8),
        Text(
          updateString,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.local_offer,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
        const SizedBox(width: 4),
        Text(
          "Tag: ",
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        Flexible(
          child: Text(
            widget.article.tags.map((tag) => "#$tag").join(", "),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTtsIconButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    // Tampilkan loading indicator
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12.0), // Samakan padding
        width: 48, // Samakan ukuran target sentuh
        height: 48,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Tampilkan tombol play/stop
    return IconButton(
      icon: Icon(
        _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
        color: _isSpeaking ? Colors.redAccent : iconColor,
        size: 26, // Sedikit lebih besar agar jelas
      ),
      onPressed: _toggleSpeech,
      padding: const EdgeInsets.all(12),
      tooltip: _isSpeaking ? 'Berhenti' : 'Dengarkan',
    );
  }

  List<Widget> _buildContentWithBlockquotes(String? content) {
    // Terapkan font size dari state
    final currentFontSize = _fontSizeMap[_currentFontSize]!;

    if (content == null || content.isEmpty) {
      if (widget.article.description != null &&
          widget.article.description!.isNotEmpty) {
        return [
          Text(
            _stripHtml(widget.article.description!),
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'SourceSerif4',
              fontWeight: FontWeight.w400,
              fontSize: currentFontSize, // Terapkan font size
              height: 1.6,
            ),
          ),
        ];
      }
      return [
        const Text(
          "Konten lengkap tidak tersedia.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontFamily: 'SourceSerif4',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ];
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> widgets = [];

    final document = parse(content);
    final body = document.body;

    if (body != null) {
      for (var element in body.children) {
        if (element.localName == 'blockquote') {
          final pTags = element.getElementsByTagName('p');
          final citeTags = element.getElementsByTagName('cite');

          final String mainQuote =
              pTags.map((p) => p.text.trim()).join('\n').trim();
          final String? authorQuote =
              citeTags.isNotEmpty ? citeTags.first.text.trim() : null;

          if (mainQuote.isNotEmpty) {
            widgets.add(
              Container(
                margin: const EdgeInsets.only(bottom: 16, top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[850]?.withOpacity(0.5)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFF39e011),
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: const Color(0xFF39e011),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        // Gunakan Column
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainQuote, // Teks kutipan (dari <p>)
                            style: TextStyle(
                              fontFamily: 'SourceSerif4',
                              fontWeight: FontWeight.bold,
                              fontSize: currentFontSize - 1, // Sesuaikan font
                              height: 1.6,
                              fontStyle: FontStyle.normal,
                              color:
                                  isDark ? Colors.grey[200] : Colors.grey[900],
                            ),
                          ),
                          if (authorQuote != null && authorQuote.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 0.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 1.2,
                                    margin: const EdgeInsets.only(
                                        top: 11, right: 8),
                                    color: const Color(0xFFE5FF10),
                                  ),
                                  Expanded(
                                    child: Text(
                                      authorQuote,
                                      style: TextStyle(
                                        fontFamily: 'SourceSerif4',
                                        fontWeight: FontWeight.normal,
                                        fontSize: currentFontSize - 2,
                                        height: 1.5,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
                                      ),
                                      maxLines: null,
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else if (element.localName == 'p') {
          final paragraphText = element.text.trim();
          if (paragraphText.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  paragraphText,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'SourceSerif4',
                    fontWeight: FontWeight.w400,
                    fontSize: currentFontSize, // Terapkan font size
                    height: 1.6,
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Text(
          _stripHtml(content),
          textAlign: TextAlign.left,
          style: TextStyle(
            fontFamily: 'SourceSerif4',
            fontWeight: FontWeight.w400,
            fontSize: currentFontSize, // Terapkan font size
            height: 1.6,
          ),
        ),
      );
    }

    return widgets;
  }

  String _getPlatformButtonText() {
    return 'Baca di Browser';
  }

  IconData _getPlatformIcon() {
    if (kIsWeb) return Icons.open_in_new;
    if (Platform.isWindows) return Icons.desktop_windows_outlined;
    if (Platform.isAndroid) return Icons.android;
    if (Platform.isIOS) return Icons.apple;
    return Icons.open_in_browser;
  }

  String _getPlatformInfoText() {
    if (kIsWeb) return 'Membuka tab baru';
    if (Platform.isWindows) return 'Membuka di browser desktop';
    if (Platform.isAndroid || Platform.isIOS)
      return 'Membuka di browser eksternal';
    return 'Membuka di browser';
  }

  IconData _getPlatformInfoIcon() {
    if (kIsWeb) return Icons.web_asset_outlined;
    if (Platform.isWindows) return Icons.desktop_windows;
    if (Platform.isAndroid) return Icons.phone_android;
    if (Platform.isIOS) return Icons.phone_iphone;
    return Icons.devices_other;
  }
}

class BookmarkIconButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  const BookmarkIconButton(
      {Key? key, required this.isBookmarked, required this.onToggle})
      : super(key: key);
  @override
  State<BookmarkIconButton> createState() => _BookmarkIconButtonState();
}

class _BookmarkIconButtonState extends State<BookmarkIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late bool _isBookmarkedLocalAnim;

  @override
  void initState() {
    super.initState();
    _isBookmarkedLocalAnim = widget.isBookmarked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant BookmarkIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBookmarked != _isBookmarkedLocalAnim) {
      _isBookmarkedLocalAnim = widget.isBookmarked;
      if (_isBookmarkedLocalAnim) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Tentukan warna ikon default berdasarkan tema
    final defaultIconColor = isDark ? Colors.white : Colors.black;

    return IconButton(
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              _isBookmarkedLocalAnim ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarkedLocalAnim
                  ? Theme.of(context).colorScheme.primary
                  : defaultIconColor,
              size: 24,
            )),
      ),
      onPressed: widget.onToggle,
      tooltip:
          widget.isBookmarked ? 'Hapus dari koleksi' : 'Simpan ke koleksi',
      padding: const EdgeInsets.all(12), // Samakan padding
    );
  }
}

class _FocusedImageView extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String title;
  final String category;
  const _FocusedImageView(
      {Key? key,
      required this.imageUrl,
      required this.heroTag,
      required this.title,
      required this.category})
      : super(key: key);
  @override
  State<_FocusedImageView> createState() => _FocusedImageViewState();
}

class _FocusedImageViewState extends State<_FocusedImageView> {
  // bool _showOverlayText = true; // <-- DIHAPUS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context), // Tap di background untuk menutup
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
                child: Hero(
                    tag: widget.heroTag,
                    // --- TAMBAHAN WRAPPER INI ---
                    // Ini memperbaiki bug "blank screen" di HP saat Hero
                    // beranimasi ke dalam Dialog.
                    child: Material(
                      type: MaterialType.transparency,
                      child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          // GestureDetector di dalam sini dihapus
                          child: CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (c, u) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (c, u, e) => const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white)))),
                    ))),
            
            // --- SEMUA BLOK "AnimatedOpacity" DIHAPUS ---
            // Ini adalah "efek" (overlay teks) yang Anda minta hilangkan.
            /*
            AnimatedOpacity(
              opacity: _showOverlayText ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showOverlayText,
                child: Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24).copyWith(top: 48),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent
                        ])),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration:
                                  const BoxDecoration(color: Colors.yellow),
                              child: Text(widget.category,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(height: 8),
                          Text(widget.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4)
                                  ]),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis)
                        ]),
                  ),
                ),
              ),
            ),
            */
            // --- AKHIR BLOK YANG DIHAPUS ---
          ],
        ),
      ),
    );
  }
}

/// Mengonversi data audio PCM mentah (dari Gemini) menjadi format WAV
Uint8List pcmToWav(Uint8List pcmData, int sampleRate, int channels, int bitDepth) {
  int pcmSize = pcmData.lengthInBytes;
  int wavSize = pcmSize + 44; // 44 byte untuk header WAV
  int byteRate = (sampleRate * channels * bitDepth) ~/ 8;
  int blockAlign = (channels * bitDepth) ~/ 8;

  final header = ByteData(44);
  final data = Uint8List(wavSize);

  // RIFF chunk
  header.setUint32(0, 0x52494646, Endian.little); // "RIFF"
  header.setUint32(4, wavSize - 8, Endian.little); // Ukuran file - 8
  header.setUint32(8, 0x57415645, Endian.little); // "WAVE"

  // "fmt " sub-chunk
  header.setUint32(12, 0x666D7420, Endian.little); // "fmt "
  header.setUint32(16, 16, Endian.little); // Ukuran sub-chunk fmt (16 untuk PCM)
  header.setUint16(20, 1, Endian.little); // Format audio (1 untuk PCM)
  header.setUint16(22, channels.toUnsigned(16), Endian.little); // Jumlah channel
  header.setUint32(24, sampleRate.toUnsigned(32), Endian.little); // Sample rate
  header.setUint32(28, byteRate.toUnsigned(32), Endian.little); // Byte rate
  header.setUint16(32, blockAlign.toUnsigned(16), Endian.little); // Block align
  header.setUint16(34, bitDepth.toUnsigned(16), Endian.little); // Bits per sample

  // "data" sub-chunk
  header.setUint32(36, 0x64617461, Endian.little); // "data"
  header.setUint32(40, pcmSize.toUnsigned(32), Endian.little); // Ukuran data PCM

  // Gabungkan header dan data PCM
  data.setAll(0, header.buffer.asUint8List());
  data.setAll(44, pcmData);

  return data;
}