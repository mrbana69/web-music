const youtubeMusicService = require('../services/youtubeMusicService');

async function testSimilar(name) {
  const radio = await youtubeMusicService.getRecommendations(name, 25);
  const seen = new Set([name.toLowerCase()]);
  const similar = [];
  for (const t of radio) {
    const aName = t.artist?.name;
    if (aName && !seen.has(aName.toLowerCase())) {
      seen.add(aName.toLowerCase());
      similar.push({
        id: t.artist?.id || `art_${aName}`,
        name: aName,
        picture: t.artist?.picture || t.album?.cover || ''
      });
    }
  }
  console.log(`Similar artists for "${name}":`);
  similar.slice(0, 8).forEach((a, i) => console.log(`  ${i+1}. ${a.name}`));
}

testSimilar('The Weeknd');
testSimilar('Sfera Ebbasta');
