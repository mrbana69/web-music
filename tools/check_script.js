const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'index.html');
const html = fs.readFileSync(file, 'utf8');
const scriptStart = html.indexOf('<script>');
const scriptEnd = html.lastIndexOf('</script>');
if (scriptStart === -1 || scriptEnd === -1) {
  console.error('No inline <script> found');
  process.exit(1);
}
const scriptContent = html.slice(scriptStart + '<script>'.length, scriptEnd);
try {
  new Function(scriptContent);
  console.log('OK - no syntax errors in inline script (Function constructor)');
} catch (e) {
  console.error('Syntax error detected:');
  console.error(e && e.stack ? e.stack : e);
  process.exit(2);
}
