import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_state.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'playlist_screen.dart';
import 'google_login_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GoogleLoginScreen()),
    );
    if (loggedIn == true && mounted) {
      final library = context.read<LibraryState>();
      final api = context.read<ApiService>();
      if (library.likedTracks.isEmpty && library.playlists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Sincronizzazione libreria YouTube Music in corso...'),
              ],
            ),
            backgroundColor: AppTheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
        await library.syncGoogleAccount(api);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Libreria sincronizzata: ${library.likedTracks.length} brani piaciuti, ${library.playlists.length} playlist!',
            ),
            backgroundColor: AppTheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final api = context.read<ApiService>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'La tua Libreria',
                      style: AppTheme.syne(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryAccent, size: 28),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Google Account Login / Profile Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: GlassContainer(
                  borderRadius: 20,
                  onTap: () {
                    if (library.isGoogleLoggedIn) {
                      _showGoogleProfileDialog(context);
                    } else {
                      _handleGoogleSignIn(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Google / Avatar Icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: library.isGoogleLoggedIn ? AppTheme.surfaceContainerHighest : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: library.isGoogleLoggedIn && (library.googleUser?.avatarUrl.isNotEmpty ?? false)
                              ? Image.network(
                                  library.googleUser!.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppTheme.primaryAccent, size: 28),
                                )
                              : library.isGoogleLoggedIn
                                  ? const Icon(Icons.person_rounded, color: AppTheme.primaryAccent, size: 28)
                                  : const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color: Color(0xFF4285F4),
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'sans-serif',
                                        ),
                                      ),
                                    ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                library.isGoogleLoggedIn
                                    ? (library.googleUser?.name ?? 'Account Google')
                                    : 'Accedi con Google',
                                style: AppTheme.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                library.isGoogleLoggedIn
                                    ? (library.googleUser?.email.isNotEmpty ?? false
                                        ? library.googleUser!.email
                                        : 'Connesso · Tocca per gestire')
                                    : 'Sincronizza preferiti e playlist YouTube Music',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.inter(
                                  color: library.isGoogleLoggedIn ? Colors.greenAccent : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (library.isGoogleLoggedIn)
                          IconButton(
                            icon: library.isSyncing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: AppTheme.primaryAccent, strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, color: AppTheme.primaryAccent),
                            onPressed: library.isSyncing
                                ? null
                                : () async {
                                    final success = await library.syncGoogleAccount(api);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? 'Libreria sincronizzata con successo!' : 'Sincronizzazione completata'),
                                          backgroundColor: AppTheme.surfaceContainerHighest,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    }
                                  },
                          )
                        else
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => _handleGoogleSignIn(context),
                            child: Text(
                              'Accedi',
                              style: AppTheme.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Liked Songs Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: GlassContainer(
                  borderRadius: 20,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistScreen(
                          title: 'Brani Preferiti',
                          subtitle: '${library.likedTracks.length} brani preferiti',
                          tracks: library.likedTracks,
                          isLikedSongs: true,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFA2D48), Color(0xFF7928CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFA2D48).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Brani Preferiti',
                                style: AppTheme.syne(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${library.likedTracks.length} brani',
                                style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Playlists Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playlist create & salvate',
                      style: AppTheme.syne(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: const Icon(Icons.add_rounded, color: AppTheme.primaryAccent, size: 20),
                      label: Text('Crea', style: AppTheme.inter(color: AppTheme.primaryAccent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            if (library.playlists.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Nessuna playlist creata. Creane una con il pulsante "+" o sincronizza da Google.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final pl = library.playlists[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: GlassContainer(
                        borderRadius: 16,
                        isBackdropEnabled: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistScreen(
                                title: pl.title,
                                subtitle: pl.subtitle,
                                tracks: pl.tracks,
                                playlistId: pl.id,
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: pl.coverUrl.isNotEmpty
                                ? Image.network(pl.coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.queue_music_rounded, color: AppTheme.primaryAccent))
                                : const Icon(Icons.queue_music_rounded, color: AppTheme.primaryAccent),
                          ),
                          title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text(pl.subtitle.isNotEmpty ? pl.subtitle : '${pl.tracks.length} brani', style: const TextStyle(color: AppTheme.textSecondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 20),
                            onPressed: () => library.deletePlaylist(pl.id),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: library.playlists.length,
                ),
              ),

            // 5. Account & Settings Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Sessione & Impostazioni',
                      style: AppTheme.syne(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 16,
                      onTap: () => _showYtmCookieDialog(context),
                      child: ListTile(
                        leading: const Icon(Icons.cookie_outlined, color: AppTheme.primaryAccent),
                        title: Text('Sessione YouTube Music (Cookie SAPISID)', style: AppTheme.syne(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          library.ytmCookie != null ? 'Sessione attiva · Feed personalizzato' : 'Opzionale (Tocca per inserire)',
                          style: AppTheme.inter(color: library.ytmCookie != null ? Colors.greenAccent : AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassContainer(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAccent.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.4)),
                                ),
                                child: Text(
                                  AppConfig.appCommit,
                                  style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Versione v${AppConfig.appVersion} ${Platform.isWindows ? "Windows Desktop" : (Platform.isAndroid ? "Android Native" : (Platform.isIOS ? "iOS Native" : (Platform.isMacOS ? "macOS Desktop" : (Platform.isLinux ? "Linux Desktop" : "Web"))))}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Build: ${AppConfig.buildTime}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      ),
    );
  }

  void _showGoogleProfileDialog(BuildContext context) {
    final library = context.read<LibraryState>();
    final user = library.googleUser;
    final api = context.read<ApiService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.account_circle_rounded, color: Color(0xFF4285F4), size: 28),
            const SizedBox(width: 10),
            const Text('Account Google', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.name ?? 'Utente Google',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (user?.email.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(user!.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.sync_rounded, color: Colors.white),
              label: const Text('Sincronizza Libreria YouTube', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await library.syncGoogleAccount(api);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Libreria sincronizzata!' : 'Sincronizzazione completata')),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.login_rounded, color: Colors.white70),
              label: const Text('Riconnetti / Cambia Account', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.pop(ctx);
                _handleGoogleSignIn(context);
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text('Disconnetti Account', style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                await library.logoutGoogle();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account Google disconnesso')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nuova Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nome playlist', hintStyle: TextStyle(color: AppTheme.textMuted)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<LibraryState>().createPlaylist(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crea', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showYtmCookieDialog(BuildContext context) {
    final library = context.read<LibraryState>();
    final ctrl = TextEditingController(text: library.ytmCookie ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sessione YouTube Music', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Incolla il token SAPISID o la stringa completa di cookie per sincronizzare la cronologia dei tuoi ascolti reali e personalizzare le Scelte Rapide:",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Incolla qui SAPISID o Cookie...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceContainerLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          if (library.ytmCookie != null)
            TextButton(
              onPressed: () {
                library.saveYtmCookie(null);
                Navigator.pop(ctx);
              },
              child: const Text('Rimuovi', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              library.saveYtmCookie(ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null);
              Navigator.pop(ctx);
            },
            child: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

