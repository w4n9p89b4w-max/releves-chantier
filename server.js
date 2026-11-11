// Relevés Chantier — serveur de synchronisation
// La tablette envoie ses dossiers ici ; le Mac et le PC les consultent.
// Sert aussi l'appli elle-même (dossier ./public).
'use strict';
const express = require('express');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const path = require('path');

const PORT = Number(process.env.PORT || 3010);
const TOKEN = process.env.RELEVES_TOKEN || '';
const DB_FILE = process.env.RELEVES_DB || path.join(__dirname, 'releves.db');
if (TOKEN.length < 12) {
  console.error('RELEVES_TOKEN manquant ou trop court (12 caractères minimum).');
  process.exit(1);
}

const db = new Database(DB_FILE);
db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS chantiers (id TEXT PRIMARY KEY, json TEXT NOT NULL, updated INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS media (id TEXT PRIMARY KEY, chantier_id TEXT NOT NULL, json TEXT NOT NULL, updated INTEGER NOT NULL);
  CREATE INDEX IF NOT EXISTS media_chantier ON media (chantier_id);
`);
const q = {
  listChantiers: db.prepare('SELECT json FROM chantiers ORDER BY updated DESC'),
  putChantier: db.prepare('INSERT INTO chantiers (id, json, updated) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET json = excluded.json, updated = excluded.updated'),
  delChantier: db.prepare('DELETE FROM chantiers WHERE id = ?'),
  mediaOf: db.prepare('SELECT json FROM media WHERE chantier_id = ? ORDER BY updated'),
  putMedia: db.prepare('INSERT INTO media (id, chantier_id, json, updated) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET chantier_id = excluded.chantier_id, json = excluded.json, updated = excluded.updated'),
  delMedia: db.prepare('DELETE FROM media WHERE id = ?'),
  delMediaOf: db.prepare('DELETE FROM media WHERE chantier_id = ?'),
  mediaIds: db.prepare("SELECT id, chantier_id AS chantierId, json_extract(json, '$.rev') AS rev FROM media"),
  mediaOne: db.prepare('SELECT json FROM media WHERE id = ?'),
  stats: db.prepare('SELECT (SELECT COUNT(*) FROM chantiers) AS chantiers, (SELECT COUNT(*) FROM media) AS media, (SELECT MAX(updated) FROM chantiers) AS updated'),
};

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', true);

// --- API protégée par le code d'accès ---
const api = express.Router();
const tokenBuf = Buffer.from(TOKEN);
const fails = new Map(); // limite les essais de code par adresse IP
api.use((req, res, next) => {
  res.set('Cache-Control', 'no-store');
  const ip = req.ip;
  const f = fails.get(ip);
  if (f && f.n >= 10 && Date.now() - f.t < 15 * 60 * 1000) return res.status(429).json({ error: 'Trop d\'essais, réessayez dans 15 minutes.' });
  const given = Buffer.from(String(req.get('x-releves-token') || ''));
  const ok = given.length === tokenBuf.length && crypto.timingSafeEqual(given, tokenBuf);
  if (!ok) {
    fails.set(ip, { n: (f && Date.now() - f.t < 15 * 60 * 1000 ? f.n : 0) + 1, t: Date.now() });
    return res.status(401).json({ error: 'Code d\'accès invalide' });
  }
  fails.delete(ip);
  next();
});
api.use(express.json({ limit: '60mb' }));

const validId = id => typeof id === 'string' && /^[\w-]{1,64}$/.test(id);

api.get('/status', (req, res) => res.json({ ok: true, ...q.stats.get() }));

api.get('/chantiers', (req, res) => {
  res.json(q.listChantiers.all().map(r => JSON.parse(r.json)));
});
api.put('/chantiers/:id', (req, res) => {
  const c = req.body;
  if (!validId(req.params.id) || !c || c.id !== req.params.id) return res.status(400).json({ error: 'Dossier invalide' });
  q.putChantier.run(c.id, JSON.stringify(c), Number(c.updated) || Date.now());
  res.json({ ok: true });
});
api.delete('/chantiers/:id', (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ error: 'Identifiant invalide' });
  db.transaction(id => { q.delMediaOf.run(id); q.delChantier.run(id); })(req.params.id);
  res.json({ ok: true });
});
api.get('/chantiers/:id/media', (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ error: 'Identifiant invalide' });
  res.json(q.mediaOf.all(req.params.id).map(r => JSON.parse(r.json)));
});
api.get('/media-ids', (req, res) => res.json(q.mediaIds.all()));
api.get('/media/:id', (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ error: 'Identifiant invalide' });
  const r = q.mediaOne.get(req.params.id);
  if (!r) return res.status(404).json({ error: 'Introuvable' });
  res.json(JSON.parse(r.json));
});
api.put('/media/:id', (req, res) => {
  const m = req.body;
  if (!validId(req.params.id) || !m || m.id !== req.params.id || !validId(m.chantierId)) return res.status(400).json({ error: 'Fichier invalide' });
  q.putMedia.run(m.id, m.chantierId, JSON.stringify(m), Number(m.created) || Date.now());
  res.json({ ok: true });
});
api.delete('/media/:id', (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ error: 'Identifiant invalide' });
  q.delMedia.run(req.params.id);
  res.json({ ok: true });
});
api.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'Fichier trop lourd (60 Mo max)' });
  console.error(err);
  res.status(500).json({ error: 'Erreur serveur' });
});
app.use('/api/releves', api);

// --- L'appli (fichiers du zip) ---
app.use(express.static(path.join(__dirname, 'public'), {
  setHeaders: (res, file) => { if (/\.(html|js|webmanifest)$/.test(file)) res.set('Cache-Control', 'no-cache'); },
}));

app.listen(PORT, '127.0.0.1', () => console.log(`Relevés Chantier : http://127.0.0.1:${PORT}`));
