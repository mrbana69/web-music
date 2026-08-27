const DEMO_TRACKS = [
  {
    id: 'demo-track-1',
    title: 'Midnight Echo',
    duration: 222000,
    duration_ms: 222000,
    artist: { id: 'artist-1', name: 'Nova Harbor', picture: 'artist-1' },
    album: { id: 'album-1', title: 'Afterglow', cover: 'album-1' },
    genres: ['Synthwave'],
    explicit: false,
    popularity: 92
  },
  {
    id: 'demo-track-2',
    title: 'Velvet Horizon',
    duration: 241000,
    duration_ms: 241000,
    artist: { id: 'artist-2', name: 'Aurora Pines', picture: 'artist-2' },
    album: { id: 'album-2', title: 'Hollow Light', cover: 'album-2' },
    genres: ['Indie Pop'],
    explicit: false,
    popularity: 88
  },
  {
    id: 'demo-track-3',
    title: 'Glass City',
    duration: 198000,
    duration_ms: 198000,
    artist: { id: 'artist-3', name: 'Lumen Drift', picture: 'artist-3' },
    album: { id: 'album-3', title: 'Night Signals', cover: 'album-3' },
    genres: ['Electronic'],
    explicit: false,
    popularity: 85
  },
  {
    id: 'demo-track-4',
    title: 'Sunset Thread',
    duration: 234000,
    duration_ms: 234000,
    artist: { id: 'artist-1', name: 'Nova Harbor', picture: 'artist-1' },
    album: { id: 'album-4', title: 'Starlight Circuit', cover: 'album-4' },
    genres: ['Dream Pop'],
    explicit: false,
    popularity: 90
  }
];

const DEMO_ARTISTS = [
  { id: 'artist-1', name: 'Nova Harbor', picture: 'artist-1', genres: ['Synthwave', 'Dream Pop'] },
  { id: 'artist-2', name: 'Aurora Pines', picture: 'artist-2', genres: ['Indie Pop', 'Alt Rock'] },
  { id: 'artist-3', name: 'Lumen Drift', picture: 'artist-3', genres: ['Electronic', 'Downtempo'] }
];

const DEMO_ALBUMS = [
  { id: 'album-1', title: 'Afterglow', cover: 'album-1', artist: { id: 'artist-1', name: 'Nova Harbor' }, year: 2024 },
  { id: 'album-2', title: 'Hollow Light', cover: 'album-2', artist: { id: 'artist-2', name: 'Aurora Pines' }, year: 2023 },
  { id: 'album-3', title: 'Night Signals', cover: 'album-3', artist: { id: 'artist-3', name: 'Lumen Drift' }, year: 2022 },
  { id: 'album-4', title: 'Starlight Circuit', cover: 'album-4', artist: { id: 'artist-1', name: 'Nova Harbor' }, year: 2025 }
];

function normalize(value = '') {
  return String(value).toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
}

function findTrackById(id) {
  return DEMO_TRACKS.find((track) => track.id === id) || null;
}

function findArtistById(id) {
  return DEMO_ARTISTS.find((artist) => artist.id === id) || null;
}

function findAlbumById(id) {
  return DEMO_ALBUMS.find((album) => album.id === id) || null;
}

function buildSearchResponse(type, query) {
  const q = normalize(query);
  const trackMatches = DEMO_TRACKS.filter((track) => {
    if (!q) return true;
    const haystack = `${track.title} ${track.artist.name} ${track.album.title}`.toLowerCase();
    return haystack.includes(q);
  });

  const artistMatches = DEMO_ARTISTS.filter((artist) => {
    if (!q) return true;
    return normalize(artist.name).includes(q);
  });

  const albumMatches = DEMO_ALBUMS.filter((album) => {
    if (!q) return true;
    return normalize(album.title).includes(q) || normalize(album.artist.name).includes(q);
  });

  if (type === 'artist') {
    return {
      data: {
        items: artistMatches,
        artists: { items: artistMatches },
        tracks: { items: trackMatches },
        albums: { items: albumMatches }
      }
    };
  }

  if (type === 'album') {
    return {
      data: {
        items: albumMatches,
        albums: { items: albumMatches },
        tracks: { items: trackMatches },
        artists: { items: artistMatches }
      }
    };
  }

  return {
    data: {
      items: trackMatches,
      tracks: { items: trackMatches },
      albums: { items: albumMatches },
      artists: { items: artistMatches }
    }
  };
}

function findBestTrackMatch({ title, artist, duration_ms }) {
  const qTitle = normalize(title);
  const qArtist = normalize(artist);
  const targetDuration = Number(duration_ms || 0);

  let best = null;
  let bestScore = -Infinity;

  for (const track of DEMO_TRACKS) {
    let score = 0;
    const trackTitle = normalize(track.title);
    const trackArtist = normalize(track.artist.name);

    if (qTitle && trackTitle.includes(qTitle)) score += 50;
    if (qArtist && trackArtist.includes(qArtist)) score += 40;
    if (qTitle && qArtist && trackTitle.includes(qTitle) && trackArtist.includes(qArtist)) score += 20;

    if (targetDuration && track.duration_ms) {
      const diff = Math.abs(track.duration_ms - targetDuration);
      if (diff <= 7000) score += 20;
      else score -= 10;
    }

    if (score > bestScore) {
      bestScore = score;
      best = track;
    }
  }

  return best || DEMO_TRACKS[0];
}

module.exports = {
  DEMO_TRACKS,
  DEMO_ARTISTS,
  DEMO_ALBUMS,
  findTrackById,
  findArtistById,
  findAlbumById,
  buildSearchResponse,
  findBestTrackMatch
};
