function formatArt(url) {
  if (!url) return '';
  let str = String(url).trim();
  if (str.includes('googleusercontent.com') || str.includes('ggpht.com')) {
    str = str.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj');
    if (!str.includes('=w500-h500-l90-rj') && !str.includes('=')) {
      str += '=w500-h500-l90-rj';
    }
    return str;
  }
  if (str.includes('i.ytimg.com')) {
    return str.replace(/\/hqdefault\.jpg/, '/maxresdefault.jpg');
  }
  return str;
}

const tests = [
  'https://yt3.googleusercontent.com/KOBKZe_Nbdah4IMDubRBU710P0C5LoSC6l7pZqGfsUZuIuyhyYwaxR-xj6V3jTigzmPy8SjVsd5j8ss=w120-h120-l90-rj',
  'https://yt3.googleusercontent.com/abc=w544-h544',
  'https://lh3.googleusercontent.com/xyz=s60-c-k',
  'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg'
];

tests.forEach(t => {
  console.log(`INPUT : ${t}`);
  console.log(`OUTPUT: ${formatArt(t)}\n`);
});

