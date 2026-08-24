#!/usr/bin/env node
// blueprint companion server. Serves the newest screen fragment from
// <project>/.brainstorm/screens/ wrapped in frame.html, pushes reloads over
// SSE, and ingests nothing: GET-only, no state beyond "which file is newest".
// Disk contract: server-info (present only while running), port (persisted so
// restarts reuse the same port and the user's open tab reconnects).
import { createServer } from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 || i === process.argv.length - 1 ? fallback : process.argv[i + 1];
}

const projectDir = arg('project-dir', null);
if (!projectDir) {
  console.error('usage: serve.mjs --project-dir <dir> [--port N] [--open] [--idle-timeout-minutes N]');
  process.exit(2);
}
const brainDir = path.join(projectDir, '.brainstorm');
const screensDir = path.join(brainDir, 'screens');
fs.mkdirSync(screensDir, { recursive: true });
const portFile = path.join(brainDir, 'port');
const infoFile = path.join(brainDir, 'server-info');
const idleMinutes = Number(arg('idle-timeout-minutes', '0')) || 0; // 0 = never exit

const frame = fs.readFileSync(path.join(SCRIPT_DIR, 'frame.html'), 'utf8');
const composerPath = path.join(SCRIPT_DIR, 'composer.js');

function newestScreen() {
  const files = fs.readdirSync(screensDir).filter((f) => f.endsWith('.html'));
  if (!files.length) return null;
  files.sort(
    (a, b) =>
      fs.statSync(path.join(screensDir, b)).mtimeMs - fs.statSync(path.join(screensDir, a)).mtimeMs,
  );
  return fs.readFileSync(path.join(screensDir, files[0]), 'utf8');
}

function page() {
  const fragment = newestScreen();
  if (fragment === null) {
    return frame.replace('<!--BLUEPRINT:CONTENT-->', '<p>No screens yet — waiting for the first round…</p>');
  }
  const head = fragment.trimStart().slice(0, 9).toLowerCase();
  if (head.startsWith('<!doctype') || head.startsWith('<html')) return fragment;
  return frame.replace('<!--BLUEPRINT:CONTENT-->', fragment);
}

const clients = new Set();
let lastActivity = Date.now();

const server = createServer((req, res) => {
  lastActivity = Date.now();
  if (req.method !== 'GET') { res.writeHead(405); res.end(); return; }
  const url = req.url.split('?')[0];
  if (url === '/') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(page());
  } else if (url === '/style.css') {
    const p = path.join(brainDir, 'style.css');
    res.writeHead(200, { 'content-type': 'text/css' });
    res.end(fs.existsSync(p) ? fs.readFileSync(p) : '');
  } else if (url === '/composer.js') {
    res.writeHead(200, { 'content-type': 'text/javascript' });
    res.end(fs.existsSync(composerPath) ? fs.readFileSync(composerPath) : '');
  } else if (url === '/events') {
    res.writeHead(200, {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      connection: 'keep-alive',
    });
    res.write('\n');
    clients.add(res);
    req.on('close', () => clients.delete(res));
  } else {
    res.writeHead(404); res.end();
  }
});

let reloadTimer = null;
fs.watch(screensDir, () => {
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(() => {
    for (const c of clients) c.write('data: reload\n\n');
  }, 100);
});

const savedPort = fs.existsSync(portFile) ? Number(fs.readFileSync(portFile, 'utf8').trim()) : 0;
const wantPort = Number(arg('port', String(savedPort))) || 0;
server.on('error', (e) => {
  // A stale persisted port may be taken by another process: fall back to any
  // free port rather than dying. Explicit --port conflicts still surface.
  if (e.code === 'EADDRINUSE' && !process.argv.includes('--port')) server.listen(0, '127.0.0.1');
  else throw e;
});
server.listen(wantPort, '127.0.0.1', () => {
  const port = server.address().port;
  fs.writeFileSync(portFile, String(port));
  const url = `http://localhost:${port}/`;
  fs.writeFileSync(infoFile, JSON.stringify({ port, pid: process.pid, url }));
  console.log(JSON.stringify({ type: 'server-started', url, screens: screensDir }));
  if (process.argv.includes('--open')) {
    spawn(process.platform === 'darwin' ? 'open' : 'xdg-open', [url], {
      stdio: 'ignore',
      detached: true,
    }).unref();
  }
});

function shutdown() {
  try { fs.unlinkSync(infoFile); } catch { /* already gone */ }
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
if (idleMinutes > 0) {
  setInterval(() => {
    if (Date.now() - lastActivity > idleMinutes * 60000) shutdown();
  }, 30000).unref();
}
