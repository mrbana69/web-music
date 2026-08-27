const youtubeMusicService = require('../services/youtubeMusicService');

async function testArtist(artistName) {
  console.log(`\n--- Testing Artist Page for "${artistName}" ---`);
  const data = await youtubeMusicService.getArtist(artistName);
  console.log('Artist Name:', data.artist.name);
  console.log('Artist Picture:', data.artist.picture);
  console.log(`Top Tracks (${data.tracks.length}):`);
  data.tracks.slice(0, 5).forEach((t, i) => console.log(`  ${i+1}. ${t.title} (${t.id})`));
  console.log(`Albums (${data.albums.length}):`);
  data.albums.slice(0, 5).forEach((a, i) => console.log(`  ${i+1}. ${a.title}`));
}

async function run() {
  await testArtist('The Weeknd');
  await testArtist('Sfera Ebbasta');
}
run();

