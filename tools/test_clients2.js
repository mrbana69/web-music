const { fetchJson } = require('../lib/httpClient');

async function testModernClients(videoId) {
  const configs = [
    {
      name: 'ANDROID_TESTSUITE',
      body: {
        context: {
          client: {
            clientName: 'ANDROID_TESTSUITE',
            clientVersion: '1.9',
            androidSdkVersion: 30,
            hl: 'en',
            gl: 'US'
          }
        },
        videoId,
        contentCheckOk: true,
        racyCheckOk: true
      }
    },
    {
      name: 'ANDROID_VR',
      body: {
        context: {
          client: {
            clientName: 'ANDROID_VR',
            clientVersion: '1.50.28',
            deviceMake: 'Oculus',
            deviceModel: 'Quest 3',
            androidSdkVersion: 32,
            hl: 'en',
            gl: 'US'
          }
        },
        videoId,
        contentCheckOk: true,
        racyCheckOk: true
      }
    },
    {
      name: 'WEB_CREATOR',
      body: {
        context: {
          client: {
            clientName: 'WEB_CREATOR',
            clientVersion: '1.20240801.01.00',
            hl: 'en',
            gl: 'US'
          }
        },
        videoId
      }
    },
    {
      name: 'IOS_EMBED',
      body: {
        context: {
          client: {
            clientName: 'IOS',
            clientVersion: '19.29.1',
            deviceMake: 'Apple',
            deviceModel: 'iPhone16,2'
          },
          thirdParty: {
            embedUrl: 'https://www.youtube.com/'
          }
        },
        videoId,
        playbackContext: {
          contentPlaybackContext: {
            html5Preference: 'HTML5_PREF_WANTS',
            signatureTimestamp: 19900
          }
        }
      }
    }
  ];

  for (const c of configs) {
    try {
      const res = await fetchJson('https://www.youtube.com/youtubei/v1/player?prettyPrint=false', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Origin': 'https://www.youtube.com',
          'X-YouTube-Client-Name': '1',
          'X-YouTube-Client-Version': '2.20240801.01.00'
        },
        body: JSON.stringify(c.body),
        timeout: 5000
      });

      const formats = res?.streamingData?.adaptiveFormats || res?.streamingData?.formats || [];
      const audioFormats = formats.filter(f => f.mimeType && f.mimeType.startsWith('audio/'));
      const directAudio = audioFormats.find(f => Boolean(f.url));
      console.log(`Config [${c.name}]: formats=${formats.length}, audio=${audioFormats.length}, directUrl=${Boolean(directAudio)}`);
      if (directAudio) {
        console.log(`  -> URL found (${directAudio.mimeType}, bitrate: ${directAudio.bitrate})!`);
      }
    } catch (e) {
      console.log(`Config [${c.name}] failed:`, e.message);
    }
  }
}

testModernClients('4NRXx6U8ABQ');

