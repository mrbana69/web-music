const DEMO_TRACKS = [
  {
    id: 'demo-track-1',
    title: 'Midnight Echo',
    duration: 222,
    duration_ms: 222000,
    artist: { id: 'artist-1', name: 'Nova Harbor' },
    album: { id: 'album-1', title: 'Afterglow', cover: 'album-1' },
    explicit: false,
    popularity: 92
  },
  {
    id: 'demo-track-2',
    title: 'Velvet Horizon',
    duration: 241,
    duration_ms: 241000,
    artist: { id: 'artist-2', name: 'Aurora Pines' },
    album: { id: 'album-2', title: 'Hollow Light', cover: 'album-2' },
    explicit: false,
    popularity: 88
  },
  {
    id: 'demo-track-3',
    title: 'Glass City',
    duration: 198,
    duration_ms: 198000,
    artist: { id: 'artist-3', name: 'Lumen Drift' },
    album: { id: 'album-3', title: 'Night Signals', cover: 'album-3' },
    explicit: false,
    popularity: 85
  },
  {
    id: 'demo-track-4',
    title: 'Sunset Thread',
    duration: 234,
    duration_ms: 234000,
    artist: { id: 'artist-1', name: 'Nova Harbor' },
    album: { id: 'album-4', title: 'Starlight Circuit', cover: 'album-4' },
    explicit: false,
    popularity: 90
  }
];

const DEMO_ARTISTS = [
  { id: 'artist-1', name: 'Nova Harbor', genres: ['Synthwave', 'Dream Pop'] },
  { id: 'artist-2', name: 'Aurora Pines', genres: ['Indie Pop', 'Alt Rock'] },
  { id: 'artist-3', name: 'Lumen Drift', genres: ['Electronic', 'Downtempo'] }
];

const DEMO_ALBUMS = [
  { id: 'album-1', title: 'Afterglow', cover: 'album-1', artist: { id: 'artist-1', name: 'Nova Harbor' }, year: 2024 },
  { id: 'album-2', title: 'Hollow Light', cover: 'album-2', artist: { id: 'artist-2', name: 'Aurora Pines' }, year: 2023 },
  { id: 'album-3', title: 'Night Signals', cover: 'album-3', artist: { id: 'artist-3', name: 'Lumen Drift' }, year: 2022 },
  { id: 'album-4', title: 'Starlight Circuit', cover: 'album-4', artist: { id: 'artist-1', name: 'Nova Harbor' }, year: 2025 }
];

function normalize(value = '') {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function getTrackById(id) {
  return DEMO_TRACKS.find((track) => track.id === id) || null;
}

function getArtistById(id) {
  return DEMO_ARTISTS.find((artist) => artist.id === id) || null;
}

function getAlbumById(id) {
  return DEMO_ALBUMS.find((album) => album.id === id) || null;
}

function buildSearchQueryData(type, query) {
  const q = normalize(query);
  const trackMatches = DEMO_TRACKS.filter((track) => {
    if (!q) return true;
    return [track.title, track.artist.name, track.album.title].some((value) => normalize(value).includes(q));
  });

  const artistMatches = DEMO_ARTISTS.filter((artist) => {
    if (!q) return true;
    return normalize(artist.name).includes(q) || artist.genres.some((genre) => normalize(genre).includes(q));
  });

  const albumMatches = DEMO_ALBUMS.filter((album) => {
    if (!q) return true;
    return normalize(album.title).includes(q) || normalize(album.artist.name).includes(q);
  });

  return {
    data: {
      items: type === 'artist' ? artistMatches : type === 'album' ? albumMatches : trackMatches,
      tracks: { items: trackMatches },
      artists: { items: artistMatches },
      albums: { items: albumMatches }
    }
  };
}

function findBestTrackMatch({ title, artist, duration_ms }) {
  const qTitle = normalize(title || '');
  const qArtist = normalize(artist || '');
  const targetDuration = Number(duration_ms || 0);

  let bestTrack = DEMO_TRACKS[0];
  let bestScore = -Infinity;

  for (const track of DEMO_TRACKS) {
    let score = 0;
    const tTitle = normalize(track.title);
    const tArtist = normalize(track.artist.name);

    if (qTitle && tTitle.includes(qTitle)) score += 50;
    if (qArtist && tArtist.includes(qArtist)) score += 40;
    if (qTitle && qArtist && tTitle.includes(qTitle) && tArtist.includes(qArtist)) score += 20;

    if (targetDuration) {
      const diff = Math.abs(track.duration_ms - targetDuration);
      if (diff <= 7000) score += 20;
      else score -= 10;
    }

    if (score > bestScore) {
      bestScore = score;
      bestTrack = track;
    }
  }

  return bestTrack;
}

function getMixById(id) {
  if (id !== 'demo-mix-1') return null;
  return { items: DEMO_TRACKS.map((track) => ({ item: track })) };
}

module.exports = {
  DEMO_TRACKS,
  DEMO_ARTISTS,
  DEMO_ALBUMS,
  getTrackById,
  getArtistById,
  getAlbumById,
  getMixById,
  buildSearchQueryData,
  findBestTrackMatch
};
