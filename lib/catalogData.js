/**
 * Fallback & Offline Catalog Data for development, testing, and offline modes.
 */

const DEMO_TRACKS = [
  {
    id: 'demo-track-1',
    title: 'Midnight Echo',
    duration: 222,
    duration_ms: 222000,
    artist: { id: 'artist-1', name: 'Nova Harbor', picture: '/icons/192x192.png' },
    artists: [{ id: 'artist-1', name: 'Nova Harbor' }],
    album: { id: 'album-1', title: 'Afterglow', cover: '/icons/512x512.png', releaseDate: '2024-04-12' },
    genres: ['Synthwave', 'Dream Pop'],
    explicit: false,
    popularity: 92,
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
  },
  {
    id: 'demo-track-2',
    title: 'Velvet Horizon',
    duration: 241,
    duration_ms: 241000,
    artist: { id: 'artist-2', name: 'Aurora Pines', picture: '/icons/192x192.png' },
    artists: [{ id: 'artist-2', name: 'Aurora Pines' }],
    album: { id: 'album-2', title: 'Hollow Light', cover: '/icons/512x512.png', releaseDate: '2023-09-20' },
    genres: ['Indie Pop', 'Alt Rock'],
    explicit: false,
    popularity: 88,
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'
  },
  {
    id: 'demo-track-3',
    title: 'Glass City',
    duration: 198,
    duration_ms: 198000,
    artist: { id: 'artist-3', name: 'Lumen Drift', picture: '/icons/192x192.png' },
    artists: [{ id: 'artist-3', name: 'Lumen Drift' }],
    album: { id: 'album-3', title: 'Night Signals', cover: '/icons/512x512.png', releaseDate: '2022-11-05' },
    genres: ['Electronic', 'Downtempo'],
    explicit: false,
    popularity: 85,
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'
  },
  {
    id: 'demo-track-4',
    title: 'Sunset Thread',
    duration: 234,
    duration_ms: 234000,
    artist: { id: 'artist-1', name: 'Nova Harbor', picture: '/icons/192x192.png' },
    artists: [{ id: 'artist-1', name: 'Nova Harbor' }],
    album: { id: 'album-4', title: 'Starlight Circuit', cover: '/icons/512x512.png', releaseDate: '2025-01-15' },
    genres: ['Dream Pop', 'Chillwave'],
    explicit: false,
    popularity: 90,
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'
  },
  {
    id: 'demo-track-5',
    title: 'Solar Flare',
    duration: 215,
    duration_ms: 215000,
    artist: { id: 'artist-2', name: 'Aurora Pines', picture: '/icons/192x192.png' },
    artists: [{ id: 'artist-2', name: 'Aurora Pines' }],
    album: { id: 'album-2', title: 'Hollow Light', cover: '/icons/512x512.png', releaseDate: '2023-09-20' },
    genres: ['Indie Pop'],
    explicit: false,
    popularity: 82,
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'
  }
];

const DEMO_ARTISTS = [
  {
    id: 'artist-1',
    name: 'Nova Harbor',
    picture: '/icons/192x192.png',
    genres: ['Synthwave', 'Dream Pop'],
    popularity: 92
  },
  {
    id: 'artist-2',
    name: 'Aurora Pines',
    picture: '/icons/192x192.png',
    genres: ['Indie Pop', 'Alt Rock'],
    popularity: 88
  },
  {
    id: 'artist-3',
    name: 'Lumen Drift',
    picture: '/icons/192x192.png',
    genres: ['Electronic', 'Downtempo'],
    popularity: 85
  }
];

const DEMO_ALBUMS = [
  {
    id: 'album-1',
    title: 'Afterglow',
    cover: '/icons/512x512.png',
    artist: { id: 'artist-1', name: 'Nova Harbor' },
    artists: [{ id: 'artist-1', name: 'Nova Harbor' }],
    releaseDate: '2024-04-12',
    year: 2024,
    type: 'ALBUM'
  },
  {
    id: 'album-2',
    title: 'Hollow Light',
    cover: '/icons/512x512.png',
    artist: { id: 'artist-2', name: 'Aurora Pines' },
    artists: [{ id: 'artist-2', name: 'Aurora Pines' }],
    releaseDate: '2023-09-20',
    year: 2023,
    type: 'ALBUM'
  },
  {
    id: 'album-3',
    title: 'Night Signals',
    cover: '/icons/512x512.png',
    artist: { id: 'artist-3', name: 'Lumen Drift' },
    artists: [{ id: 'artist-3', name: 'Lumen Drift' }],
    releaseDate: '2022-11-05',
    year: 2022,
    type: 'EP'
  },
  {
    id: 'album-4',
    title: 'Starlight Circuit',
    cover: '/icons/512x512.png',
    artist: { id: 'artist-1', name: 'Nova Harbor' },
    artists: [{ id: 'artist-1', name: 'Nova Harbor' }],
    releaseDate: '2025-01-15',
    year: 2025,
    type: 'SINGLE'
  }
];

function getTrackById(id) {
  return DEMO_TRACKS.find((t) => String(t.id) === String(id)) || null;
}

function getArtistById(id) {
  return DEMO_ARTISTS.find((a) => String(a.id) === String(id)) || null;
}

function getAlbumById(id) {
  return DEMO_ALBUMS.find((al) => String(al.id) === String(id)) || null;
}

function getMixById(id) {
  return {
    id: id || 'demo-mix-1',
    title: 'Daily Mix',
    items: DEMO_TRACKS.map((track) => ({ item: track }))
  };
}

module.exports = {
  DEMO_TRACKS,
  DEMO_ARTISTS,
  DEMO_ALBUMS,
  getTrackById,
  getArtistById,
  getAlbumById,
  getMixById
};

