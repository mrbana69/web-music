import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/library_state.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../theme/app_theme.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  late final WebViewController _controller;
  static const MethodChannel _nativeCookiesChannel = MethodChannel('com.preluded.music/cookies');

  bool _isLoading = true;
  bool _isExtracting = false;
  double _progress = 0.0;
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile; rv:128.0) Gecko/128.0 Firefox/128.0',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress / 100.0);
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
            _checkAuthStatus(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkAuthStatus(url);
          },
          onUrlChange: (change) {
            if (change.url != null) {
              _checkAuthStatus(change.url!);
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F'),
      );

    // Periodically check auth status every 1.5 seconds while on screen
    _periodicCheckTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && !_isExtracting) {
        _extractAndAuthenticate(isManual: false);
      }
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  Future<String> _extractAllCookies() async {
    final Map<String, String> cookieMap = {};

    // 1. YouTube Music domains MUST be prioritized.
    // Cookies belonging to .youtube.com (SAPISID, __Secure-3PAPISID, LOGIN_INFO, SID)
    // must NEVER be overwritten by .google.com cookies, otherwise SAPISIDHASH fails on music.youtube.com.
    final domains = [
      'https://music.youtube.com',
      'https://www.youtube.com',
      'https://youtube.com',
      'https://accounts.google.com',
    ];

    // 1. Android Native CookieManager via MethodChannel (Essential for HttpOnly & secure cookies)
    for (final domain in domains) {
      try {
        final nativeCookieStr = await _nativeCookiesChannel.invokeMethod<String>('getCookies', {'url': domain});
        if (nativeCookieStr != null && nativeCookieStr.isNotEmpty) {
          final parts = nativeCookieStr.split(';');
          for (final p in parts) {
            final kv = p.split('=');
            if (kv.length >= 2) {
              final k = kv[0].trim();
              final v = kv.sublist(1).join('=').trim();
              if (k.isNotEmpty && !cookieMap.containsKey(k)) {
                cookieMap[k] = v;
              }
            }
          }
        }
      } catch (e) {
        print('[GoogleLoginScreen] Native cookie error for $domain: $e');
      }
    }

    // 2. Document cookie fallback
    try {
      final jsCookie = await _controller.runJavaScriptReturningResult('document.cookie');
      String docStr = jsCookie.toString();
      if (docStr.startsWith('"') && docStr.endsWith('"') && docStr.length > 1) {
        docStr = docStr.substring(1, docStr.length - 1);
      }
      docStr = docStr.replaceAll(r'\"', '"');
      final parts = docStr.split(';');
      for (final p in parts) {
        final kv = p.split('=');
        if (kv.length >= 2) {
          final k = kv[0].trim();
          final v = kv.sublist(1).join('=').trim();
          if (k.isNotEmpty && !cookieMap.containsKey(k)) {
            cookieMap[k] = v;
          }
        }
      }
    } catch (_) {}

    return cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> _checkAuthStatus(String url) async {
    print('[GoogleLoginScreen] Navigation to: $url');
    await _extractAndAuthenticate(isManual: false);
  }

  Future<void> _extractAndAuthenticate({bool isManual = false}) async {
    if (_isExtracting || !mounted) return;
    _isExtracting = true;

    try {
      final rawCookies = await _extractAllCookies();
      final hasSapisid = rawCookies.contains('SAPISID') ||
          rawCookies.contains('__Secure-3PAPISID') ||
          rawCookies.contains('__Secure-1PAPISID');
      final hasLogin = rawCookies.contains('LOGIN_INFO') || rawCookies.contains('SID');
      final hasAuth = hasSapisid || hasLogin;

      if (!hasAuth) {
        _isExtracting = false;
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Completa prima l\'accesso con email e password su Google/YouTube.'),
              backgroundColor: AppTheme.surfaceContainerHighest,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      print('[GoogleLoginScreen] Auth detected! hasSapisid: $hasSapisid, hasLogin: $hasLogin. Starting extraction...');
      _periodicCheckTimer?.cancel();
      if (mounted) setState(() {});

      final api = context.read<ApiService>();
      final library = context.read<LibraryState>();

      // 1. Save cookies immediately
      await library.saveYtmCookie(rawCookies);

      // 2. Fetch profile info with safety timeout (max 3 seconds)
      GoogleUser? fetchedUser;
      try {
        fetchedUser = await api.fetchYtmAccountInfo(rawCookies).timeout(const Duration(seconds: 3));
      } catch (_) {}

      final user = fetchedUser ?? GoogleUser(
        name: 'Account Google',
        email: '',
        cookie: rawCookies,
      );

      await library.loginWithGoogle(user);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accesso effettuato come ${user.name}!'),
            backgroundColor: AppTheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'accesso: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Accedi con Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'YouTube Music Sync',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Ricarica pagina',
            onPressed: () => _controller.reload(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isExtracting ? null : () => _extractAndAuthenticate(isManual: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Fatto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                  minHeight: 2,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isExtracting)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Accesso in corso...',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sincronizzazione account YouTube Music',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () {
                          if (mounted) setState(() => _isExtracting = false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Annulla operazione'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

