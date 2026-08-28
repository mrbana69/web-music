const http = require('http');
const app = require('../server');

const server = http.createServer(app);
server.listen(0, async () => {
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;
  console.log(`Test server listening on ${baseUrl}`);

  try {
    const res = await fetch(`${baseUrl}/api/auth/google/library?token=demo_token`);
    console.log('Status:', res.status);
    const data = await res.json();
    console.log('Response data:', data);
  } catch (e) {
    console.error('Error:', e);
  } finally {
    server.close();
  }
});

