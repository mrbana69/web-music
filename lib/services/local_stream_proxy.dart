// proxy
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'storage_service.dart';

class LocalStreamProxy {
  static final LocalStreamProxy _instance = LocalStreamProxy._internal();
  factory LocalStreamProxy() => _instance;
  LocalStreamProxy._internal();

  StorageService? storage;
  HttpServer? _server;
  final YoutubeExplode _yt = YoutubeExplode();
  final HttpClient _httpClient = HttpClient()
    ..idleTimeout = const Duration(seconds: 15)
    ..connectionTimeout = const Duration(seconds: 8);

  final Map<String, List<StreamInfo>> _cachedStreamInfos = {};
  final Map<String, DateTime> _cacheTimes = {};

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      print('[LocalStreamProxy] Started listening on http://127.0.0.1:$port');
      _server!.listen(_handleRequest, onError: (e) {
        print('[LocalStreamProxy] Server error: $e');
      });
    } catch (e) {
      print('[LocalStreamProxy] Failed to start server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _yt.close();
    _httpClient.close(force: true);
  }

  String getStreamUrl(String videoId) {
    if (_server == null) {
      throw StateError('LocalStreamProxy is not running. Call start() first.');
    }
    return 'http://127.0.0.1:$port/stream?id=${Uri.encodeComponent(videoId)}';
  }

  String? _generateSapisidHash(String cookieString, [String origin = 'https://music.youtube.com']) {
    try {
      final cookieMap = <String, String>{};
      for (final part in cookieString.split(';')) {
        final idx = part.indexOf('=');
        if (idx != -1) {
          final k = part.substring(0, idx).trim();
          final v = part.substring(idx + 1).trim();
          if (k.isNotEmpty) cookieMap[k] = v;
        }
      }
      final sapisid = cookieMap['__Secure-3PAPISID'] ?? cookieMap['SAPISID'] ?? cookieMap['__Secure-1PAPISID'];
      if (sapisid == null || sapisid.isEmpty) return null;

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final input = '$timestamp $sapisid $origin';
      final digest = sha1.convert(utf8.encode(input));
      return 'SAPISIDHASH ${timestamp}_$digest';
    } catch (_) {
      return null;
    }
  }

  Future<List<StreamInfo>> _getAudioStreams(String videoId) async {
    final cached = _cachedStreamInfos[videoId];
    final time = _cacheTimes[videoId];
    if (cached != null && time != null && DateTime.now().difference(time).inMinutes < 60) {
      return cached;
    }

    final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
    final result = <StreamInfo>[];

    // Priority 1: itag 18 from manifest.muxed (Universal MP4 container, AAC stereo audio).
    // YouTube signs itag 18 with &ratebypass=yes, completely bypassing BotGuard/SABR 1MB cutoff.
    // ExoPlayer natively hardware-decodes the AAC audio with 0 issues.
    try {
      final muxed18 = manifest.muxed.where((s) => s.tag == 18).toList();
      if (muxed18.isNotEmpty) {
        result.addAll(muxed18);
        print('[LocalStreamProxy] Added itag 18 (ratebypass=yes) for $videoId');
      }
    } catch (_) {}

    // Priority 2: audioOnly streams (itag 140 AAC 128k, itag 251 Opus 160k, etc.)
    final audios = manifest.audioOnly.toList();
    audios.sort((a, b) {
      int score(AudioStreamInfo s) {
        if (s.tag == 140) return 100;
        if (s.tag == 251) return 90;
        if (s.tag == 250) return 70;
        if (s.tag == 139) return 50;
        return s.bitrate.bitsPerSecond;
      }
      return score(b).compareTo(score(a));
    });
    result.addAll(audios);

    // Priority 3: any remaining muxed streams
    if (result.isEmpty && manifest.muxed.isNotEmpty) {
      result.addAll(manifest.muxed);
    }

    _cachedStreamInfos[videoId] = result;
    _cacheTimes[videoId] = DateTime.now();
    return result;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final vId = req.uri.queryParameters['id'] ?? '';
    if (vId.isEmpty) {
      req.response.statusCode = HttpStatus.badRequest;
      req.response.write('Missing videoId');
      await req.response.close();
      return;
    }

    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    bool headerSent = false;

    try {
      final audios = await _getAudioStreams(vId);
      if (audios.isEmpty) {
        req.response.statusCode = HttpStatus.notFound;
        req.response.write('No audio streams found');
        await req.response.close();
        return;
      }

      final userCookie = storage?.getYtmCookie();
      final sapisidHash = (userCookie != null && userCookie.isNotEmpty) ? _generateSapisidHash(userCookie) : null;

      for (final audio in audios) {
        final totalBytes = audio.size.totalBytes;
        if (totalBytes <= 0) continue;

        int start = 0;
        int end = totalBytes - 1;

        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          if (parts[0].isNotEmpty) {
            start = int.tryParse(parts[0]) ?? 0;
          }
          if (parts.length > 1 && parts[1].isNotEmpty) {
            end = int.tryParse(parts[1]) ?? (totalBytes - 1);
          }
        }

        // Clamp boundaries
        start = start.clamp(0, totalBytes - 1);
        end = end.clamp(start, totalBytes - 1);
        final contentLength = end - start + 1;

        req.response.statusCode = (rangeHeader != null) ? HttpStatus.partialContent : HttpStatus.ok;
        final mimeType = audio.codec.mimeType.isNotEmpty ? audio.codec.mimeType : 'audio/mp4';
        req.response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
        req.response.headers.set(HttpHeaders.contentLengthHeader, contentLength.toString());
        req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        if (rangeHeader != null) {
          req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalBytes');
        }
        headerSent = true;

        // Stream upstream in 512KB safe segments with retry
        const chunkSize = 512 * 1024;
        int currentOffset = start;
        bool audioFormatWorked = true;

        try {
          while (currentOffset <= end) {
            final chunkEnd = (currentOffset + chunkSize - 1).clamp(0, end);
            bool chunkSuccess = false;

            for (int retry = 0; retry < 2; retry++) {
              try {
                final upstreamReq = await _httpClient.getUrl(audio.url);
                upstreamReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$currentOffset-$chunkEnd');
                upstreamReq.headers.set(
                  HttpHeaders.userAgentHeader,
                  'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
                );
                if (userCookie != null && userCookie.isNotEmpty) {
                  upstreamReq.headers.set(HttpHeaders.cookieHeader, userCookie);
                  if (sapisidHash != null) {
                    upstreamReq.headers.set(HttpHeaders.authorizationHeader, sapisidHash);
                  }
                }

                final upstreamRes = await upstreamReq.close().timeout(const Duration(seconds: 10));
                if (upstreamRes.statusCode == HttpStatus.partialContent || upstreamRes.statusCode == HttpStatus.ok) {
                  await req.response.addStream(upstreamRes);
                  chunkSuccess = true;
                  break;
                } else {
                  print('[LocalStreamProxy] Upstream chunk $currentOffset-$chunkEnd for itag ${audio.tag} failed: HTTP ${upstreamRes.statusCode} (retry $retry)');
                  await upstreamRes.drain().catchError((_) {});
                }
              } catch (chunkErr) {
                print('[LocalStreamProxy] Upstream chunk network error: $chunkErr (retry $retry)');
              }
            }

            if (!chunkSuccess) {
              audioFormatWorked = false;
              break;
            }

            currentOffset = chunkEnd + 1;
          }

          if (audioFormatWorked) {
            await req.response.close();
            return;
          }
        } catch (pipeError) {
          // Client disconnected or seeked; normal behavior for media players
          try {
            await req.response.close();
          } catch (_) {}
          return;
        }

        // If this audio format failed mid-stream, headers have already been sent to client,
        // so we cannot retry another audio format for this HTTP connection.
        if (headerSent) {
          try {
            await req.response.close();
          } catch (_) {}
          return;
        }
      }

      if (!headerSent) {
        req.response.statusCode = HttpStatus.serviceUnavailable;
        await req.response.close().catchError((_) {});
      }
    } catch (e) {
      print('[LocalStreamProxy] Request failed for $vId: $e');
      if (!headerSent) {
        try {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
        } catch (_) {}
      } else {
        try {
          await req.response.close();
        } catch (_) {}
      }
    }
  }
}

