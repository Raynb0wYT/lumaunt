import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const root = fileURLToPath(new URL('../', import.meta.url));
export const output = path.join(root, 'dist');
export async function build() {
  // Cache-bust just public source modules so dev changes rebuild without a framework.
  const configPath = new URL('../src/config.js', import.meta.url);
  const pagesPath = new URL('../src/pages.js', import.meta.url);
  const configSource = await readFile(configPath, 'utf8');
  const configModule = `data:text/javascript;base64,${Buffer.from(configSource).toString('base64')}`;
  const legalSource = await readFile(new URL('../src/legal.js', import.meta.url), 'utf8');
  const legalModule = `data:text/javascript;base64,${Buffer.from(legalSource).toString('base64')}`;
  const pagesSource = (await readFile(pagesPath, 'utf8')).replace("'./config.js'", JSON.stringify(configModule)).replace("'./legal.js'", JSON.stringify(legalModule));
  const { renderPage, routes } = await import(`data:text/javascript;base64,${Buffer.from(pagesSource).toString('base64')}`);
  const publicPath = path.join(root, 'public');
  const { site } = await import(configModule);
  const assets = {};
  for (const [key, source] of [['app', site.screenshot], ['discord', site.discordScreenshot]]) {
    try {
      const bytes = await readFile(path.join(publicPath, source.slice(1)));
      if (bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error(`${source} must be a genuine PNG asset.`);
      assets[key] = { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      console.warn(`Screenshot pending: ${source}`);
    }
  }
  await rm(output, { recursive: true, force: true });
  await mkdir(output, { recursive: true });
  await cp(publicPath, output, { recursive: true, filter: (source) => !source.endsWith('.md') });
  for (const route of routes) {
    const directory = path.join(output, route.slice(1));
    await mkdir(directory, { recursive: true });
    await writeFile(path.join(directory, 'index.html'), renderPage(route, { assets }));
  }
  await writeFile(path.join(output, '404.html'), renderPage('/404'));
  await writeFile(path.join(output, 'robots.txt'), 'User-agent: *\nAllow: /\nSitemap: https://lumaunt.app/sitemap.xml\n');
  await writeFile(path.join(output, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${routes.filter(route => !route.startsWith('/auth/')).map(route => `<url><loc>https://lumaunt.app${route === '/' ? '/' : route + '/'}</loc></url>`).join('')}</urlset>`);
  console.log(`Built ${routes.length} static pages → website/dist (${Object.keys(assets).length}/2 screenshots supplied).`);
}
if (process.argv[1] === fileURLToPath(import.meta.url)) await build();
