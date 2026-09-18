const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const filePath = path.join(__dirname, '..', 'web_simulator.html');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Simulator live at http://localhost:${PORT}/`);
});
