const fs = require('fs');
const path = require('path');

const files = ['index.html', 'app.html'];
for (const f of files) {
  const filePath = path.join(__dirname, '..', f);
  if (!fs.existsSync(filePath)) continue;
  const html = fs.readFileSync(filePath, 'utf8');
  const scriptStart = html.indexOf('<script>');
  const scriptEnd = html.lastIndexOf('</script>');
  if (scriptStart !== -1 && scriptEnd !== -1) {
    const scriptContent = html.slice(scriptStart + '<script>'.length, scriptEnd);
    try {
      new Function(scriptContent);
      console.log(`OK - no syntax errors in ${f}`);
    } catch (e) {
      console.error(`Syntax error detected in ${f}:`, e.message);
      process.exit(1);
    }
  }
}
console.log('All files validated successfully.');
