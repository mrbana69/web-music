/**
 * InnerTune-style Fuzzy Track Matcher
 * Computes text similarity, token set ratio, and applies duration mismatch penalties.
 */

function cleanText(str = '') {
  return String(str)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove accents
    .toLowerCase()
    .replace(/\(.*?\)/g, '')         // remove parentheses (e.g. Official Video, Remastered)
    .replace(/\[.*?\]/g, '')         // remove brackets
    .replace(/\b(ft|feat|featuring|official|video|audio|lyrics|lyric|remaster|remastered|hd|hq|4k)\b/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function levenshteinDistance(s1, s2) {
  if (s1 === s2) return 0;
  if (!s1.length) return s2.length;
  if (!s2.length) return s1.length;

  const row = [];
  for (let i = 0; i <= s2.length; i++) row[i] = i;

  for (let i = 1; i <= s1.length; i++) {
    let prev = i;
    for (let j = 1; j <= s2.length; j++) {
      const val = s1[i - 1] === s2[j - 1] ? row[j - 1] : Math.min(row[j - 1], prev, row[j]) + 1;
      row[j - 1] = prev;
      prev = val;
    }
    row[s2.length] = prev;
  }
  return row[s2.length];
}

function stringSimilarity(s1, s2) {
  const c1 = cleanText(s1);
  const c2 = cleanText(s2);
  if (!c1 || !c2) return 0;
  if (c1 === c2) return 100;

  const maxLen = Math.max(c1.length, c2.length);
  if (maxLen === 0) return 100;
  const dist = levenshteinDistance(c1, c2);
  return Math.max(0, Math.round((1 - dist / maxLen) * 100));
}

function tokenSetSimilarity(s1, s2) {
  const t1 = new Set(cleanText(s1).split(' ').filter(Boolean));
  const t2 = new Set(cleanText(s2).split(' ').filter(Boolean));
  if (t1.size === 0 || t2.size === 0) return 0;

  let intersectionCount = 0;
  for (const token of t1) {
    if (t2.has(token)) intersectionCount++;
  }

  const unionCount = new Set([...t1, ...t2]).size;
  return Math.round((intersectionCount / unionCount) * 100);
}

/**
 * Score a single candidate track against the target query/metadata
 * Target: { title, artist, duration_ms }
 * Candidate: { id, title, artist, duration_ms }
 */
function scoreTrackMatch(target, candidate) {
  const targetTitle = target.title || '';
  const targetArtist = target.artist || (target.artists && target.artists[0]?.name) || '';
  const targetDurationMs = Number(target.duration_ms || target.duration * 1000 || 0);

  const candTitle = candidate.title || '';
  const candArtist = typeof candidate.artist === 'string'
    ? candidate.artist
    : (candidate.artist?.name || (candidate.artists && candidate.artists[0]?.name) || '');
  const candDurationMs = Number(candidate.duration_ms || (candidate.duration ? candidate.duration * 1000 : 0));

  // 1. Title matching (0 to 50 points)
  const titleLev = stringSimilarity(targetTitle, candTitle);
  const titleTok = tokenSetSimilarity(targetTitle, candTitle);
  const titleScore = Math.max(titleLev, titleTok) * 0.5;

  // 2. Artist matching (0 to 30 points)
  const artistLev = stringSimilarity(targetArtist, candArtist);
  const artistTok = tokenSetSimilarity(targetArtist, candArtist);
  const artistScore = Math.max(artistLev, artistTok) * 0.3;

  // 3. Exact combined boost (0 to 10 points)
  let exactBoost = 0;
  if (cleanText(targetTitle) === cleanText(candTitle)) exactBoost += 5;
  if (cleanText(targetArtist) === cleanText(candArtist)) exactBoost += 5;

  // 4. Duration difference penalty / bonus (-30 to +10 points)
  let durationScore = 0;
  if (targetDurationMs > 0 && candDurationMs > 0) {
    const diffMs = Math.abs(targetDurationMs - candDurationMs);
    if (diffMs <= 7000) {
      // Within +- 7 seconds tolerance
      durationScore = 10;
    } else if (diffMs <= 15000) {
      durationScore = 0;
    } else if (diffMs <= 30000) {
      durationScore = -15;
    } else {
      // Significant difference (likely podcast, full live concert, or radio edit mismatch)
      durationScore = -35;
    }
  }

  const finalScore = Math.max(0, Math.min(100, Math.round(titleScore + artistScore + exactBoost + durationScore)));

  return {
    score: finalScore,
    details: {
      titleScore,
      artistScore,
      durationScore,
      candTitle,
      candArtist,
      candDurationMs
    }
  };
}

/**
 * Finds the highest scoring track candidate among an array of candidates
 */
function findBestCandidate(target, candidates = []) {
  if (!candidates || candidates.length === 0) return null;

  let best = null;
  let bestScore = -1;

  for (const candidate of candidates) {
    const { score } = scoreTrackMatch(target, candidate);
    if (score > bestScore) {
      bestScore = score;
      best = { ...candidate, score };
    }
  }

  return best;
}

module.exports = {
  cleanText,
  stringSimilarity,
  tokenSetSimilarity,
  scoreTrackMatch,
  findBestCandidate
};

