import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/services/api_service.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/models/playlist.dart';
import 'package:preluded_music/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  group('Google & YouTube Music Sync Unit Tests', () {
    test('1. fetchYtmAccountInfo parses activeAccountHeaderRenderer correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('account_menu')) {
          expect(request.headers['Authorization'], startsWith('SAPISIDHASH '));
          expect(request.headers['Cookie'], contains('SAPISID=test_yt_sapisid'));
          return http.Response(
            jsonEncode({
              'actions': [
                {
                  'openPopupAction': {
                    'popup': {
                      'multiPageMenuRenderer': {
                        'header': {
                          'activeAccountHeaderRenderer': {
                            'accountName': {
                              'runs': [{'text': 'Mario Rossi'}]
                            },
                            'email': {
                              'runs': [{'text': 'mario.rossi@gmail.com'}]
                            },
                            'accountPhoto': {
                              'thumbnails': [
                                {'url': 'https://lh3.googleusercontent.com/avatar1=s64'},
                                {'url': 'https://lh3.googleusercontent.com/avatar2=s128'}
                              ]
                            }
                          }
                        }
                      }
                    }
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ApiService(storage, mockClient);
      final user = await api.fetchYtmAccountInfo('SAPISID=test_yt_sapisid; LOGIN_INFO=test_login');

      expect(user, isNotNull);
      expect(user!.name, equals('Mario Rossi'));
      expect(user.email, equals('mario.rossi@gmail.com'));
      expect(user.avatarUrl, contains('avatar2'));
      expect(user.cookie, contains('SAPISID=test_yt_sapisid'));
    });

    test('2. syncGoogleLibrary parses VLLM and FEmusic_library_playlists', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final browseId = body['browseId']?.toString() ?? '';

        if (request.url.path.contains('account_menu')) {
          return http.Response(
            jsonEncode({
              'actions': [
                {
                  'openPopupAction': {
                    'popup': {
                      'multiPageMenuRenderer': {
                        'header': {
                          'activeAccountHeaderRenderer': {
                            'accountName': {'runs': [{'text': 'Mario Rossi'}]},
                            'email': {'runs': [{'text': 'mario@test.com'}]},
                            'accountPhoto': {'thumbnails': [{'url': 'https://avatar.png'}]}
                          }
                        }
                      }
                    }
                  }
                }
              ]
            }),
            200,
          );
        }

        if (browseId == 'VLLM') {
          return http.Response(
            jsonEncode({
              'contents': {
                'singleColumnBrowseResultsRenderer': {
                  'tabs': [
                    {
                      'tabRenderer': {
                        'content': {
                          'sectionListRenderer': {
                            'contents': [
                              {
                                'musicPlaylistShelfRenderer': {
                                  'contents': [
                                    {
                                      'musicResponsiveListItemRenderer': {
                                        'playlistItemData': {'videoId': 'vid_track_1'},
                                        'flexColumns': [
                                          {
                                            'musicResponsiveListItemFlexColumnRenderer': {
                                              'text': {
                                                'runs': [{'text': 'Canzone Uno'}]
                                              }
                                            }
                                          },
                                          {
                                            'musicResponsiveListItemFlexColumnRenderer': {
                                              'text': {
                                                'runs': [
                                                  {
                                                    'text': 'Artista Uno',
                                                    'navigationEndpoint': {
                                                      'browseEndpoint': {'browseId': 'UC_artist_1'}
                                                    }
                                                  }
                                                ]
                                              }
                                            }
                                          },
                                          {
                                            'musicResponsiveListItemFlexColumnRenderer': {
                                              'text': {
                                                'runs': [
                                                  {
                                                    'text': 'Album Uno',
                                                    'navigationEndpoint': {
                                                      'browseEndpoint': {
                                                        'browseId': 'MPREb_album_1',
                                                        'browseEndpointContextSupportedConfigs': {
                                                          'browseEndpointContextMusicConfig': {
                                                            'pageType': 'MUSIC_PAGE_TYPE_ALBUM'
                                                          }
                                                        }
                                                      }
                                                    }
                                                  }
                                                ]
                                              }
                                            }
                                          }
                                        ],
                                        'fixedColumns': [
                                          {
                                            'musicResponsiveListItemFixedColumnRenderer': {
                                              'text': {
                                                'runs': [{'text': '3:45'}]
                                              }
                                            }
                                          }
                                        ],
                                        'thumbnail': {
                                          'musicThumbnailRenderer': {
                                            'thumbnail': {
                                              'thumbnails': [
                                                {'url': 'https://i.ytimg.com/vi/vid_track_1/hqdefault.jpg'}
                                              ]
                                            }
                                          }
                                        }
                                      }
                                    },
                                    {
                                      'playlistPanelVideoRenderer': {
                                        'videoId': 'vid_track_2',
                                        'title': {
                                          'runs': [{'text': 'Canzone Due'}]
                                        },
                                        'shortBylineText': {
                                          'runs': [{'text': 'Artista Due'}]
                                        },
                                        'longBylineText': {
                                          'runs': [
                                            {
                                              'text': 'Artista Due',
                                              'navigationEndpoint': {
                                                'browseEndpoint': {
                                                  'browseId': 'UC_artist_2',
                                                  'browseEndpointContextSupportedConfigs': {
                                                    'browseEndpointContextMusicConfig': {
                                                      'pageType': 'MUSIC_PAGE_TYPE_ARTIST'
                                                    }
                                                  }
                                                }
                                              }
                                            },
                                            {
                                              'text': 'Album Due',
                                              'navigationEndpoint': {
                                                'browseEndpoint': {
                                                  'browseId': 'MPREb_album_2',
                                                  'browseEndpointContextSupportedConfigs': {
                                                    'browseEndpointContextMusicConfig': {
                                                      'pageType': 'MUSIC_PAGE_TYPE_ALBUM'
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          ]
                                        },
                                        'lengthText': {
                                          'runs': [{'text': '4:12'}]
                                        },
                                        'thumbnail': {
                                          'thumbnails': [
                                            {'url': 'https://i.ytimg.com/vi/vid_track_2/hqdefault.jpg'}
                                          ]
                                        }
                                      }
                                    }
                                  ]
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              }
            }),
            200,
          );
        }

        if (browseId == 'FEmusic_library_playlists') {
          return http.Response(
            jsonEncode({
              'contents': {
                'singleColumnBrowseResultsRenderer': {
                  'tabs': [
                    {
                      'tabRenderer': {
                        'content': {
                          'sectionListRenderer': {
                            'contents': [
                              {
                                'gridRenderer': {
                                  'items': [
                                    {
                                      'musicTwoRowItemRenderer': {
                                        'title': {
                                          'runs': [{'text': 'I Miei Preferiti Pop'}]
                                        },
                                        'subtitle': {
                                          'runs': [{'text': 'Playlist • 25 brani'}]
                                        },
                                        'navigationEndpoint': {
                                          'browseEndpoint': {'browseId': 'VLPL_custom_playlist_1'}
                                        },
                                        'thumbnailRenderer': {
                                          'musicThumbnailRenderer': {
                                            'thumbnail': {
                                              'thumbnails': [
                                                {'url': 'https://i.ytimg.com/pl/1.jpg'}
                                              ]
                                            }
                                          }
                                        }
                                      }
                                    }
                                  ]
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        return http.Response(jsonEncode({}), 200);
      });

      final api = ApiService(storage, mockClient);
      final result = await api.syncGoogleLibrary(cookie: 'SAPISID=youtube_sapisid_123; LOGIN_INFO=youtube_login_info');

      expect(result['user'], isNotNull);
      final user = result['user'] as GoogleUser;
      expect(user.name, equals('Mario Rossi'));

      final likedSongs = result['likedSongs'] as List<Track>;
      expect(likedSongs.length, equals(2));

      // Track 1
      expect(likedSongs[0].id, equals('vid_track_1'));
      expect(likedSongs[0].title, equals('Canzone Uno'));
      expect(likedSongs[0].artistName, equals('Artista Uno'));
      expect(likedSongs[0].artistId, equals('UC_artist_1'));
      expect(likedSongs[0].albumName, equals('Album Uno'));
      expect(likedSongs[0].albumId, equals('MPREb_album_1'));
      expect(likedSongs[0].durationMs, equals(225000)); // 3:45
      expect(likedSongs[0].isLiked, isTrue);

      // Track 2 (from playlistPanelVideoRenderer)
      expect(likedSongs[1].id, equals('vid_track_2'));
      expect(likedSongs[1].title, equals('Canzone Due'));
      expect(likedSongs[1].artistName, equals('Artista Due'));
      expect(likedSongs[1].albumName, equals('Album Due'));
      expect(likedSongs[1].durationMs, equals(252000)); // 4:12
      expect(likedSongs[1].isLiked, isTrue);

      final playlists = result['playlists'] as List<Playlist>;
      expect(playlists.length, equals(1));
      expect(playlists[0].id, equals('PL_custom_playlist_1'));
      expect(playlists[0].title, equals('I Miei Preferiti Pop'));
      expect(playlists[0].subtitle, contains('25 brani'));
    });

    test('3. Desktop & Mobile cookie precedence guarantees YouTube SAPISID over Google SAPISID', () async {
      // Simulate raw cookies from desktop WebView2 where Google domain and YouTube domain both provide SAPISID and SID
      final cookies = [
        {'name': 'SAPISID', 'value': 'google_sapisid_wrong', 'domain': '.google.com'},
        {'name': 'SID', 'value': 'google_sid_wrong', 'domain': '.google.com'},
        {'name': 'LOGIN_INFO', 'value': 'yt_login_correct', 'domain': '.youtube.com'},
        {'name': 'SAPISID', 'value': 'yt_sapisid_correct', 'domain': '.youtube.com'},
        {'name': 'SID', 'value': 'yt_sid_correct', 'domain': '.youtube.com'},
      ];

      final Map<String, String> cookieMap = {};

      // 1. Base / Google cookies first
      for (final c in cookies) {
        if (!c['domain']!.toLowerCase().contains('youtube.com')) {
          cookieMap[c['name']!] = c['value']!;
        }
      }

      // 2. Overwrite with .youtube.com cookies
      for (final c in cookies) {
        if (c['domain']!.toLowerCase().contains('youtube.com')) {
          cookieMap[c['name']!] = c['value']!;
        }
      }

      final cookieStr = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

      expect(cookieMap['SAPISID'], equals('yt_sapisid_correct'));
      expect(cookieMap['SID'], equals('yt_sid_correct'));
      expect(cookieMap['LOGIN_INFO'], equals('yt_login_correct'));
      expect(cookieStr, contains('SAPISID=yt_sapisid_correct'));
      expect(cookieStr, isNot(contains('google_sapisid_wrong')));

      // Test that ApiService uses this cookie to construct valid headers
      await storage.setYtmCookie(cookieStr);
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], startsWith('SAPISIDHASH '));
        expect(request.headers['Cookie'], contains('SAPISID=yt_sapisid_correct'));
        return http.Response(jsonEncode({}), 200);
      });

      final api = ApiService(storage, mockClient);
      await api.fetchQuickPicks(); // trigger request with cookie
    });
  });
}
