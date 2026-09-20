import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  WebViewController? _controller;
  static const MethodChannel _nativeCookiesChannel = MethodChannel('com.preluded.music/cookies');

  bool _isLoading = true;
  bool _isExtracting = false;
  double _progress = 0.0;
  Timer? _periodicCheckTimer;

  // Desktop WebView2 state
  Webview? _desktopWebview;
  bool _isDesktopWindowOpen = false;
  String _desktopStatus = 'Preparazione accesso...';
  bool _desktopSuccess = false;
  bool _isVerifyingDesktopAuth = false;
  GoogleUser? _detectedUser;
  String _currentDesktopUrl = '';

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDesktopWebview();
      });
      return;
    }

    final loginUserAgent = kIsWeb || _isDesktop
        ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
        : 'Mozilla/5.0 (Linux; Android 14; Mobile; rv:128.0) Gecko/128.0 Firefox/128.0';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(loginUserAgent)
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
    try {
      _desktopWebview?.close();
      _desktopWebview = null;
    } catch (_) {}
    super.dispose();
  }

  void _showManualCookieDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF4285F4), size: 22),
            SizedBox(width: 10),
            Text('Accesso con Cookie / Token', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se la finestra WebView2 non si apre o preferisci usare i tuoi cookie di YouTube Music, incollali qui sotto (deve includere SAPISID o LOGIN_INFO):',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Incolla qui i cookie (es. SAPISID=...; LOGIN_INFO=...)',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: AppTheme.surfaceContainerLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _handleSuccessfulDesktopAuth(text);
              }
            },
            child: const Text('Collega Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalBrowser() async {
    final opened = await launchUrl(
      Uri.parse('https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Il browser esterno non condivide i cookie con l\'app. Per completare il collegamento usa la finestra integrata o incolla i cookie verificati.'),
      ),
    );
  }

  Future<void> _openDesktopWebview() async {
    if (_desktopWebview != null) return;

    setState(() {
      _desktopSuccess = false;
      _detectedUser = null;
      _currentDesktopUrl = '';
      _isLoading = true;
      _isDesktopWindowOpen = true;
      _desktopStatus = 'Apertura finestra browser per accesso Google...';
    });

    try {
      final isAvailable = await WebviewWindow.isWebviewAvailable();
      if (!isAvailable) {
        throw Exception('WebView2 Runtime non rilevato nel sistema.');
      }

      final appSupportDir = await getApplicationSupportDirectory();
      final profileDir = Directory('${appSupportDir.path}/web_profile');
      if (!await profileDir.exists()) {
        try {
          await profileDir.create(recursive: true);
        } catch (e) {
          debugPrint('[GoogleLoginScreen Desktop] Could not create profile directory: $e');
        }
      }
      final cleanProfilePath = profileDir.path.replaceAll('/', '\\');

      Webview? webview;
      try {
        webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            windowWidth: 540,
            windowHeight: 760,
            title: 'Accesso Google - Preluded Music',
            userDataFolderWindows: cleanProfilePath,
          ),
        );
      } catch (e1) {
        debugPrint('[GoogleLoginScreen] Retrying WebviewWindow.create with default config: $e1');
        webview = await WebviewWindow.create(
          configuration: const CreateConfiguration(
            windowWidth: 540,
            windowHeight: 760,
            title: 'Accesso Google - Preluded Music',
          ),
        );
      }

      _desktopWebview = webview;

      // Set genuine Chrome Desktop User-Agent so Google never flags embedded WebView
      try {
        await webview.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
        );
      } catch (e) {
        debugPrint('[GoogleLoginScreen Desktop] Could not set custom UserAgent: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _desktopStatus = 'Accedi con le tue credenziali Google nella finestra aperta.';
        });
      }

      // DO NOT register setOnUrlRequestCallback: in WebView2, intercepting navigations
      // cancels POST requests and 302 token exchanges, which breaks Google 2FA prompts.
      // We rely on passive cookie detection via getAllCookies() in _periodicCheckTimer.

      _periodicCheckTimer?.cancel();
      _periodicCheckTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (_desktopWebview != null && !_isExtracting && !_desktopSuccess) {
          _checkDesktopAuth();
        }
      });

      webview.onClose.whenComplete(() {
        _periodicCheckTimer?.cancel();
        _desktopWebview = null;
        if (mounted) {
          setState(() {
            _isDesktopWindowOpen = false;
            if (!_isExtracting && !_desktopSuccess) {
              _desktopStatus = 'Finestra chiusa. Se non hai completato l\'accesso, puoi riaprirla o usare i metodi sotto.';
            }
          });
        }
      });

      await _launchDesktopUrlWhenReady(webview);
    } catch (e) {
      debugPrint('[GoogleLoginScreen Desktop] Error creating webview window: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDesktopWindowOpen = false;
          _desktopStatus = 'Impossibile aprire la finestra integrata ($e).\nPuoi usare il browser esterno o incollare i cookie sotto.';
        });
      }
    }
  }

  Future<void> _launchDesktopUrlWhenReady(Webview webview) async {
    const url =
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F';

    // create() can complete before the native WebView2 controller is ready.
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        await webview.getAllCookies();
        // Let WebView2 perform the initial navigation directly. The plugin's
        // URL interception cancels NavigationStarting until the Dart callback
        // answers, which can leave the first page blank.
        webview.launch(url, triggerOnUrlRequestEvent: false);
        // launch() is fire-and-forget in desktop_webview_window. Do not call
        // reload here: it can race the initial navigation and blank the page.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await webview.bringToForeground();
        return;
      } catch (e) {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  Future<void> _checkDesktopAuth({bool isManual = false}) async {
    if (_desktopWebview == null || _isExtracting || _isVerifyingDesktopAuth || _desktopSuccess) return;
    _isVerifyingDesktopAuth = true;

    try {
      // 1. Estrai cookie nativi da WebView2
      final cookies = await _desktopWebview!.getAllCookies();

      final ytCookies = cookies.where((c) {
        final d = c.domain.toLowerCase().replaceAll('\u0000', '').trim();
        return d.endsWith('youtube.com') || d.contains('youtube.com');
      }).toList();

      final hasYtLogin = ytCookies.any((c) => c.name.replaceAll('\u0000', '').trim() == 'LOGIN_INFO');
      final hasYtSapisid = ytCookies.any((c) {
        final n = c.name.replaceAll('\u0000', '').trim();
        return n == 'SAPISID' || n == '__Secure-3PAPISID' || n == '__Secure-1PAPISID';
      });
      final hasYtSid = ytCookies.any((c) {
        final n = c.name.replaceAll('\u0000', '').trim();
        return n == 'SID' || n == '__Secure-3PSID' || n == '__Secure-1PSID';
      });

      // Probe current page status, username and avatar via JavaScript
      String pageUserName = '';
      String pageAvatar = '';
      bool onMusicHome = false;
      bool isYtLoggedIn = false;

      try {
        final jsProbe = await _desktopWebview!.evaluateJavaScript('''
          (function() {
            var name = '';
            var avatar = '';
            var hostname = window.location.hostname || '';
            var isYtm = (hostname === 'music.youtube.com');
            var loggedIn = false;
            try {
              if (window.ytcfg) {
                name = window.ytcfg.get('USER_NAME') || '';
                loggedIn = Boolean(window.ytcfg.get('LOGGED_IN'));
              }
            } catch(e) {}
            try {
              var avatarBtn = document.querySelector('button#avatar-btn, ytmusic-avatar');
              if (avatarBtn) loggedIn = true;
              var img = document.querySelector('button#avatar-btn img, ytmusic-nav-bar #avatar-btn img');
              if (img && img.src && !img.src.includes('logo') && !img.src.includes('svg')) {
                avatar = img.src;
              }
            } catch(e) {}
            return JSON.stringify({hostname: hostname, isYtm: isYtm, loggedIn: loggedIn, name: name, avatar: avatar});
          })()
        ''');
        if (jsProbe != null) {
          var clean = jsProbe.trim();
          if (clean.startsWith('"') && clean.endsWith('"') && clean.length > 1) {
            try { clean = jsonDecode(clean); } catch (_) {}
          }
          final dynamic map = jsonDecode(clean);
          if (map is Map) {
            final hostname = map['hostname']?.toString() ?? '';
            onMusicHome = (hostname == 'music.youtube.com');
            isYtLoggedIn = (map['loggedIn'] == true);
            pageUserName = map['name']?.toString() ?? '';
            pageAvatar = map['avatar']?.toString() ?? '';
          }
        }
      } catch (e) {
        debugPrint('[GoogleLoginScreen Desktop] jsProbe error: $e');
      }

      debugPrint('[GoogleLoginScreen Desktop] probe: onMusicHome=$onMusicHome, isYtLoggedIn=$isYtLoggedIn, hasYtLogin=$hasYtLogin, hasYtSapisid=$hasYtSapisid, hasYtSid=$hasYtSid, totalCookies=${cookies.length}');

      // Authentication is ONLY possible if:
      // 1. YouTube login cookie is present (LOGIN_INFO)
      // 2. YouTube session/API auth is present (SAPISID or SID)
      // 3. Current page is music.youtube.com OR user triggered manual verification
      final isPotentialAuth = hasYtLogin && (hasYtSapisid || hasYtSid) && (onMusicHome || isManual);

      if (isPotentialAuth) {
        final Map<String, String> cookieMap = {};

        // 1. Base / Google cookies first
        for (final c in cookies) {
          final n = c.name.replaceAll('\u0000', '').trim();
          final v = c.value.replaceAll('\u0000', '').trim();
          final d = c.domain.toLowerCase().replaceAll('\u0000', '').trim();
          if (!d.contains('youtube.com') && n.isNotEmpty && v.isNotEmpty) {
            cookieMap[n] = v;
          }
        }

        // 2. Overwrite with .youtube.com cookies
        for (final c in ytCookies) {
          final n = c.name.replaceAll('\u0000', '').trim();
          final v = c.value.replaceAll('\u0000', '').trim();
          final d = c.domain.toLowerCase().replaceAll('\u0000', '').trim();
          if (!d.contains('music.youtube.com') && n.isNotEmpty && v.isNotEmpty) {
            cookieMap[n] = v;
          }
        }

        // 3. Overwrite with music.youtube.com cookies (most specific)
        for (final c in ytCookies) {
          final n = c.name.replaceAll('\u0000', '').trim();
          final v = c.value.replaceAll('\u0000', '').trim();
          final d = c.domain.toLowerCase().replaceAll('\u0000', '').trim();
          if (d.contains('music.youtube.com') && n.isNotEmpty && v.isNotEmpty) {
            cookieMap[n] = v;
          }
        }

        final cookieStr = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
        if (!mounted) return;
        final api = context.read<ApiService>();

        GoogleUser? verifiedUser;
        try {
          verifiedUser = await api
              .fetchYtmAccountInfo(cookieStr)
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('[GoogleLoginScreen Desktop] account verification check error: $e');
        }

        // Periodic check: ONLY trigger success if Innertube validated the real account!
        // Never fall back to dummy "Utente Google" during periodic polling, as that prematurely closes login.
        if (verifiedUser != null) {
          await _handleSuccessfulDesktopAuth(cookieStr, verifiedUser: verifiedUser);
          return;
        }

        // Manual check ("Fatto" button clicked): if verifiedUser is null, allow fallback if page probe found user
        if (isManual && (pageUserName.isNotEmpty || isYtLoggedIn)) {
          verifiedUser = GoogleUser(
            name: pageUserName.isNotEmpty ? pageUserName : 'Utente Google',
            email: '',
            avatarUrl: pageAvatar,
            cookie: cookieStr,
          );
          await _handleSuccessfulDesktopAuth(cookieStr, verifiedUser: verifiedUser);
          return;
        }
      }

      if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accesso non ancora rilevato. Assicurati di essere connesso a YouTube Music nella finestra aperta.')),
        );
      }
    } catch (e) {
      debugPrint('[GoogleLoginScreen Desktop] check error: $e');
    } finally {
      _isVerifyingDesktopAuth = false;
    }
  }

  Future<void> _handleSuccessfulDesktopAuth(String rawCookies, {GoogleUser? verifiedUser}) async {
    if (_isExtracting || _desktopSuccess || !mounted) return;
    _isExtracting = true;
    _periodicCheckTimer?.cancel();

    setState(() {
      _desktopStatus = 'Accesso rilevato! Sincronizzazione profilo in corso...';
    });

    try {
      final api = context.read<ApiService>();
      final library = context.read<LibraryState>();

      // 1. Salva i cookie di sessione
      await library.saveYtmCookie(rawCookies);

      // 2. Recupera info profilo reale YouTube Music
      GoogleUser? fetchedUser = verifiedUser;
      try {
        fetchedUser ??= await api.fetchYtmAccountInfo(rawCookies).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[GoogleLoginScreen Desktop] fetchYtmAccountInfo error: $e');
      }

      if (fetchedUser == null) {
        throw Exception('Cookie non autenticati o accesso Google non completato.');
      }

      final user = fetchedUser;

      await library.loginWithGoogle(user);

      // 3. Sincronizzazione immediata di brani piaciuti e playlist
      if (mounted) {
        setState(() {
          _desktopStatus = 'Sincronizzazione brani preferiti e playlist in corso...';
        });
      }

      try {
        await library.syncGoogleAccount(api).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[GoogleLoginScreen Desktop] syncGoogleAccount error: $e');
      }

      // 4. Chiudi la finestra WebView2
      try {
        _desktopWebview?.close();
        _desktopWebview = null;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _desktopSuccess = true;
          _detectedUser = library.googleUser ?? user;
          _desktopStatus = 'Sincronizzazione completata! (${library.likedTracks.length} preferiti, ${library.playlists.length} playlist)';
        });

        // Ritorno automatico dopo 2 secondi
        Timer(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _desktopStatus = 'Errore durante la sincronizzazione: $e';
        });
      }
    }
  }


  Future<String> _extractAllCookies() async {
    final Map<String, String> cookieMap = {};

    // 1. YouTube Music domains MUST be prioritized over Google accounts domains.
    final domains = [
      'https://accounts.google.com',
      'https://youtube.com',
      'https://www.youtube.com',
      'https://music.youtube.com',
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
              if (k.isNotEmpty) {
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
    if (_controller != null) {
      try {
        final jsCookie = await _controller!.runJavaScriptReturningResult('document.cookie');
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
            if (k.isNotEmpty) {
              cookieMap[k] = v;
            }
          }
        }
      } catch (_) {}
    }

    return cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> _checkAuthStatus(String url) async {
    print('[GoogleLoginScreen] Navigation to: $url');
    if (!url.contains('music.youtube.com') && !url.contains('youtube.com')) {
      return;
    }
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
      final hasAuth = hasSapisid && hasLogin;

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

      // 1. Verify the account before persisting any cookie state.
      GoogleUser? fetchedUser;
      try {
        fetchedUser = await api.fetchYtmAccountInfo(rawCookies).timeout(const Duration(seconds: 5));
      } catch (_) {}

      if (fetchedUser == null || fetchedUser.email.isEmpty) {
        _isExtracting = false;
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accesso non ancora completato. Completa il login Google e riprova.')),
          );
        }
        return;
      }

      // 2. Save only verified cookies.
      await library.saveYtmCookie(rawCookies);

      final user = fetchedUser;

      await library.loginWithGoogle(user);

      if (mounted) {
        Navigator.pop(context, true);
      }

      // Sync library data in the background so login is not blocked by it.
      unawaited(() async {
        try {
          await library.syncGoogleAccount(api).timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('[GoogleLoginScreen Mobile] syncGoogleAccount error: $e');
        }
      }());
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
          if (!_isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
              tooltip: 'Ricarica pagina',
              onPressed: () => _controller?.reload(),
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
      body: _isDesktop
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _desktopSuccess
                        ? Colors.greenAccent.withOpacity(0.4)
                        : Colors.white.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _desktopSuccess
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 44),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Accesso completato!',
                            style: AppTheme.syne(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Autenticato come:\n${_detectedUser?.name ?? 'Utente Google'}',
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text(
                              'Ritorna all\'App',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Accesso Google su Windows',
                            style: AppTheme.syne(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _desktopStatus,
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (_isExtracting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Sincronizzazione in corso...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )
                          else if (_isDesktopWindowOpen) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)),
                                    ),
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Finestra aperta: se sei connesso clicca sotto',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _isExtracting ? null : () => _checkDesktopAuth(isManual: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4285F4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.check_circle_rounded, size: 20),
                              label: const Text('Ho effettuato l\'accesso (Sincronizza)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ]
                          else ...[
                            ElevatedButton.icon(
                              onPressed: _openDesktopWebview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Riapri Finestra Accesso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _openExternalBrowser,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.public_rounded, size: 18),
                              label: const Text('Apri Browser Esterno (solo fallback)', style: TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _showManualCookieDialog,
                              icon: const Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF4285F4)),
                              label: const Text('Incolla Cookie / Token', style: TextStyle(color: Color(0xFF4285F4), fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () => _checkDesktopAuth(),
                                icon: const Icon(Icons.sync_rounded, size: 16, color: AppTheme.textSecondary),
                                label: const Text('Verifica Ora', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annulla', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            )

          : Stack(
              children: [
                if (_controller != null) WebViewWidget(controller: _controller!),
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

