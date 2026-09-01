const fs = require('fs');

function auditFile(filepath) {
  console.log('====================================================');
  console.log(` AUDITING: ${filepath}`);
  console.log('====================================================');

  const content = fs.readFileSync(filepath, 'utf8');

  // Extract all script contents
  const scriptRegex = /<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  let allJs = '';
  while ((match = scriptRegex.exec(content)) !== null) {
    allJs += match[1] + '\n';
  }

  // 1. Collect all declared function names
  const declaredFunctions = new Set();
  const funcRegex = /function\s+([a-zA-Z0-9_$]+)\s*\(/g;
  while ((match = funcRegex.exec(allJs)) !== null) {
    declaredFunctions.add(match[1]);
  }

  // Async functions
  const asyncFuncRegex = /async\s+function\s+([a-zA-Z0-9_$]+)\s*\(/g;
  while ((match = asyncFuncRegex.exec(allJs)) !== null) {
    declaredFunctions.add(match[1]);
  }

  // Arrow function variables and class declarations
  const arrowFuncRegex = /(?:const|let|var)\s+([a-zA-Z0-9_$]+)\s*=\s*(?:\([^)]*\)|[a-zA-Z0-9_$]+)\s*=>/g;
  while ((match = arrowFuncRegex.exec(allJs)) !== null) {
    declaredFunctions.add(match[1]);
  }

  const classRegex = /class\s+([a-zA-Z0-9_$]+)/g;
  while ((match = classRegex.exec(allJs)) !== null) {
    declaredFunctions.add(match[1]);
  }

  // Collect declared variables (top-level and global)
  const declaredVars = new Set();
  const varRegex = /(?:const|let|var)\s+([a-zA-Z0-9_$]+)\s*=/g;
  while ((match = varRegex.exec(allJs)) !== null) {
    declaredVars.add(match[1]);
  }

  // Global browser and standard APIs
  const browserGlobals = new Set([
    'window', 'document', 'navigator', 'localStorage', 'sessionStorage', 'console',
    'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval', 'fetch', 'Math', 'JSON',
    'Array', 'Object', 'String', 'Number', 'Boolean', 'Date', 'RegExp', 'Map', 'Set', 'Promise',
    'Error', 'TypeError', 'RangeError', 'ReferenceError', 'encodeURIComponent', 'decodeURIComponent',
    'atob', 'btoa', 'parseInt', 'parseFloat', 'isNaN', 'isFinite', 'alert', 'confirm', 'prompt',
    'Audio', 'AudioContext', 'webkitAudioContext', 'MediaMetadata', 'Image', 'URL', 'URLSearchParams',
    'Event', 'CustomEvent', 'MutationObserver', 'IntersectionObserver', 'ResizeObserver', 'caches',
    'crypto', 'location', 'history', 'screen', 'performance', 'requestAnimationFrame', 'cancelAnimationFrame',
    'HTMLElement', 'Element', 'Node', 'FormData', 'Blob', 'FileReader', 'AbortController', 'YT',
    'desktopAPI', 'indexedDB', 'IDBKeyRange', 'MediaSource', 'SourceBuffer', 'WebAssembly', 'Intl'
  ]);

  const jsKeywords = new Set([
    'if', 'for', 'while', 'switch', 'catch', 'function', 'return', 'typeof', 'delete',
    'void', 'new', 'import', 'super', 'case', 'else', 'do', 'in', 'of', 'instanceof',
    'throw', 'try', 'finally', 'with', 'default', 'break', 'continue', 'yield', 'await'
  ]);

  console.log(`-> Found ${declaredFunctions.size} declared functions/classes.`);
  console.log(`-> Found ${declaredVars.size} declared top-level variables.`);

  // 2. Audit all HTML inline event handlers (onclick, oninput, onchange, etc.)
  const handlerRegex = /\s(on[a-z]+)=([\"'])(.*?)\2/gi;
  const inlineErrors = [];
  while ((match = handlerRegex.exec(content)) !== null) {
    const attr = match[1];
    const code = match[3];

    // Find function calls inside handler
    const callRegex = /([a-zA-Z0-9_$]+)\s*\(/g;
    let callMatch;
    while ((callMatch = callRegex.exec(code)) !== null) {
      const fn = callMatch[1];
      // Check if it's a method call like e.stopPropagation() or this.focus()
      const isMethod = new RegExp('\\.' + fn + '\\s*\\(').test(code);
      if (!isMethod && !declaredFunctions.has(fn) && !declaredVars.has(fn) && !browserGlobals.has(fn) && !jsKeywords.has(fn)) {
        inlineErrors.push({ attr, code, undefinedFunction: fn });
      }
    }
  }

  if (inlineErrors.length > 0) {
    console.error(`❌ Found ${inlineErrors.length} undefined functions in inline HTML event handlers:`);
    console.error(inlineErrors);
  } else {
    console.log('✅ ALL inline HTML event handlers point to valid declared functions.');
  }

  // 3. Scan JavaScript body for direct un-scoped function calls
  const directCallRegex = /(?<![.\w$])([a-zA-Z0-9_$]+)\s*\(/g;
  const missingCalls = new Set();
  while ((match = directCallRegex.exec(allJs)) !== null) {
    const fn = match[1];
    if (
      !declaredFunctions.has(fn) &&
      !declaredVars.has(fn) &&
      !browserGlobals.has(fn) &&
      !jsKeywords.has(fn)
    ) {
      missingCalls.add(fn);
    }
  }

  if (missingCalls.size > 0) {
    console.warn('⚠️  Unresolved function identifiers called directly in JS:');
    console.warn(Array.from(missingCalls));
  } else {
    console.log('✅ ALL function calls in JS resolve to declared symbols or standard Web APIs.');
  }
}

auditFile('app.html');
auditFile('index.html');
