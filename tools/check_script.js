const fs = require('fs');
const path = require('path');

const files = ['index.html', 'app.html'];
for (const f of files) {
  const filePath = path.join(__dirname, '..', f);
  if (!fs.existsSync(filePath)) continue;
  const html = fs.readFileSync(filePath, 'utf8');
  const scriptRegex = /<script(?:\s+[^>]*)?>([\s\S]*?)<\/script>/gi;
  let match;
  let scriptIndex = 1;
  while ((match = scriptRegex.exec(html)) !== null) {
    const scriptContent = match[1];
    // Skip external script tags with only src
    if (!scriptContent.trim()) continue;
    try {
      new Function(scriptContent);
    } catch (e) {
      console.error(`Syntax error detected in ${f} (script #${scriptIndex}):`, e.message);
      process.exit(1);
    }
    scriptIndex++;
  }
  console.log(`OK - no syntax errors in ${f}`);
}
console.log('All files validated successfully.');
