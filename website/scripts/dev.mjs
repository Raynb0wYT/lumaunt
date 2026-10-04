import { createServer } from 'node:http';
import { watch } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { build, root, output } from './build.mjs';

await build();
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.png': 'image/png', '.xml': 'application/xml', '.txt': 'text/plain; charset=utf-8' };
const server = createServer(async (request, response) => {
  try {
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405, { Allow: 'GET, HEAD' }).end(); return;
    }
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let filename = path.resolve(output, `.${pathname}`);
    if (filename !== output && !filename.startsWith(output + path.sep)) {
      response.writeHead(403).end(); return;
    }
    if ((await stat(filename)).isDirectory()) filename = path.join(filename, 'index.html');
    const bytes = await readFile(filename);
    response.writeHead(200, { 'Content-Type': types[path.extname(filename)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
    response.end(request.method === 'HEAD' ? undefined : bytes);
  } catch {
    try {
      const notFound = await readFile(path.join(output, '404.html'));
      response.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      response.end(request.method === 'HEAD' ? undefined : notFound);
    } catch {
      response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end(request.method === 'HEAD' ? undefined : 'Page not found.');
    }
  }
});
const port = Number(process.env.PORT ?? 4321);
server.listen(port, '127.0.0.1', () => console.log(`Lumaunt website: http://localhost:${port}`));
server.on('error', error => { console.error(error.message); process.exitCode = 1; });
let rebuilding = Promise.resolve();
let debounce;
watch(root, { recursive: true }, (_, filename) => {
  if (!filename || !/^(src|public)[/\\]/.test(filename)) return;
  clearTimeout(debounce);
  debounce = setTimeout(() => {
    rebuilding = rebuilding.then(build).catch(error => console.error('Build failed:', error.message));
  }, 100);
});
