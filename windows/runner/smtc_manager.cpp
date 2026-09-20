#include "smtc_manager.h"

#include <windows.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>

#include <flutter/encodable_value.h>

#include <iostream>
#include <mutex>

using namespace winrt;
using namespace Windows::Media;
using namespace Windows::Foundation;
using namespace Windows::Storage::Streams;

namespace {
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;
SystemMediaTransportControls g_smtc{nullptr};
event_token g_buttonToken{};
std::mutex g_mutex;
HWND g_hwnd = nullptr;

void OnButtonPressed(SystemMediaTransportControls const&,
                     SystemMediaTransportControlsButtonPressedEventArgs const& args) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_channel) return;

  switch (args.Button()) {
    case SystemMediaTransportControlsButton::Play:
      g_channel->InvokeMethod("onPlay", nullptr);
      break;
    case SystemMediaTransportControlsButton::Pause:
      g_channel->InvokeMethod("onPause", nullptr);
      break;
    case SystemMediaTransportControlsButton::Next:
      g_channel->InvokeMethod("onNext", nullptr);
      break;
    case SystemMediaTransportControlsButton::Previous:
      g_channel->InvokeMethod("onPrevious", nullptr);
      break;
    case SystemMediaTransportControlsButton::Stop:
      g_channel->InvokeMethod("onStop", nullptr);
      break;
    default:
      break;
  }
}
}  // namespace

void SmtcManager::Initialize(HWND hwnd, flutter::BinaryMessenger* messenger) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_hwnd = hwnd;

  try {
    auto interop = winrt::try_get_activation_factory<ISystemMediaTransportControlsInterop>(
        L"Windows.Media.SystemMediaTransportControls");
    if (interop) {
      HRESULT hr = interop->GetForWindow(
          hwnd, winrt::guid_of<SystemMediaTransportControls>(), winrt::put_abi(g_smtc));
      if (SUCCEEDED(hr) && g_smtc) {
        g_smtc.IsPlayEnabled(true);
        g_smtc.IsPauseEnabled(true);
        g_smtc.IsNextEnabled(true);
        g_smtc.IsPreviousEnabled(true);
        g_smtc.IsEnabled(true);
        g_smtc.PlaybackStatus(MediaPlaybackStatus::Closed);

        g_buttonToken = g_smtc.ButtonPressed(OnButtonPressed);
      }
    }
  } catch (...) {
    // WinRT SMTC initialization fallback
  }

  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.preluded.music/smtc",
      &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_smtc) {
      result->Success();
      return;
    }

    try {
      if (call.method_name() == "updatePlayback") {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args) {
          std::string title;
          std::string artist;
          std::string album;
          std::string thumbUrl;
          bool isPlaying = false;

          auto itTitle = args->find(flutter::EncodableValue("title"));
          if (itTitle != args->end() && std::holds_alternative<std::string>(itTitle->second)) {
            title = std::get<std::string>(itTitle->second);
          }
          auto itArtist = args->find(flutter::EncodableValue("artist"));
          if (itArtist != args->end() && std::holds_alternative<std::string>(itArtist->second)) {
            artist = std::get<std::string>(itArtist->second);
          }
          auto itAlbum = args->find(flutter::EncodableValue("album"));
          if (itAlbum != args->end() && std::holds_alternative<std::string>(itAlbum->second)) {
            album = std::get<std::string>(itAlbum->second);
          }
          auto itThumb = args->find(flutter::EncodableValue("thumbnailUrl"));
          if (itThumb != args->end() && std::holds_alternative<std::string>(itThumb->second)) {
            thumbUrl = std::get<std::string>(itThumb->second);
          }
          auto itPlaying = args->find(flutter::EncodableValue("isPlaying"));
          if (itPlaying != args->end() && std::holds_alternative<bool>(itPlaying->second)) {
            isPlaying = std::get<bool>(itPlaying->second);
          }

          auto updater = g_smtc.DisplayUpdater();
          // Match the process AppUserModelID so Windows attributes the
          // media session to Preluded instead of showing an unknown app.
          updater.AppMediaId(L"Preluded.Music");
          updater.Type(MediaPlaybackType::Music);
          auto musicProps = updater.MusicProperties();
          musicProps.Title(winrt::to_hstring(title));
          musicProps.Artist(winrt::to_hstring(artist));
          musicProps.AlbumTitle(winrt::to_hstring(album));

          if (!thumbUrl.empty() && (thumbUrl.rfind("http://", 0) == 0 || thumbUrl.rfind("https://", 0) == 0)) {
            try {
              Uri uri(winrt::to_hstring(thumbUrl));
              updater.Thumbnail(RandomAccessStreamReference::CreateFromUri(uri));
            } catch (...) {
              updater.Thumbnail(nullptr);
            }
          } else {
            updater.Thumbnail(nullptr);
          }

          updater.Update();

          g_smtc.PlaybackStatus(isPlaying ? MediaPlaybackStatus::Playing
                                          : MediaPlaybackStatus::Paused);
        }
        result->Success();
      } else if (call.method_name() == "setPlaybackStatus") {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args) {
          auto itPlaying = args->find(flutter::EncodableValue("isPlaying"));
          if (itPlaying != args->end() && std::holds_alternative<bool>(itPlaying->second)) {
            bool isPlaying = std::get<bool>(itPlaying->second);
            g_smtc.PlaybackStatus(isPlaying ? MediaPlaybackStatus::Playing
                                            : MediaPlaybackStatus::Paused);
          }
        }
        result->Success();
      } else if (call.method_name() == "clearPlayback") {
        g_smtc.PlaybackStatus(MediaPlaybackStatus::Closed);
        auto updater = g_smtc.DisplayUpdater();
        updater.ClearAll();
        updater.Update();
        result->Success();
      } else {
        result->NotImplemented();
      }
    } catch (...) {
      result->Success();
    }
  });
}

void SmtcManager::Dispose() {
  std::lock_guard<std::mutex> lock(g_mutex);
  try {
    if (g_smtc) {
      if (g_buttonToken.value != 0) {
        g_smtc.ButtonPressed(g_buttonToken);
        g_buttonToken.value = 0;
      }
      g_smtc.PlaybackStatus(MediaPlaybackStatus::Closed);
      g_smtc = nullptr;
    }
  } catch (...) {}
  g_channel = nullptr;
}

