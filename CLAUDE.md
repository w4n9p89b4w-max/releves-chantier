# Relevés Chantier : notes du projet

Appli de visite de chantier d'Etienne (EcoTole) : iPad = tablette principale qui garde tous les dossiers,
Mac / PC = consultation en lecture seule. En ligne : https://releves.fayetcardoso.fr (Raspberry de la maison).
Répondre en français, simplement (l'utilisateur n'est pas développeur).

## Fichiers
- `public/index.html` : toute l'appli (HTML + CSS + JS dans un seul fichier). C'est la version de référence.
- `public/sw.js` : mode hors ligne. **Changer le numéro `releves-vNN` à chaque mise à jour de l'appli**, sinon l'iPad garde l'ancienne version.
- `public/manifest.webmanifest`, icônes : installation sur l'écran d'accueil.
- `server.js` : Express + SQLite (better-sqlite3), port 3010. Sert `public/` et l'API `/api/releves/*`
  (protégée par l'en-tête `x-releves-token` = RELEVES_TOKEN). Tables `chantiers` et `media` (photos, croquis, fichiers en data: URI).
- `installer-pi.sh` : installation en une commande sur le Pi (service `releves-chantier`, code dans `/etc/releves-chantier.env`).
- `mettre-a-jour.sh` : lancé par le timer `releves-chantier-maj.timer` toutes les 5 min : `git fetch` + `reset --hard origin/main`, `npm install` si package.json change, redémarre le service.
- `lancer.bat` : essai local sur Windows (http://localhost:3010, code `code-de-test-local`, base `releves-test.db`).

## Mise en ligne
- Pousser sur `main` suffit : le Pi récupère la nouvelle version en 5 minutes au plus.
- Pi : `etiennefayetpi` (192.168.1.48 à la maison), Debian 13, Node 24 via nvm. Dossier `~/releves-chantier`, base `~/releves-chantier/releves.db` (à sauvegarder, jamais sur GitHub).
- Cloudflare Tunnel (même tunnel que le budget) : nom d'hôte public `releves.fayetcardoso.fr` → HTTP `localhost:3010`.
  Conseillé : application Cloudflare Access sur cette adresse (données clients).
- Commandes utiles sur le Pi : `sudo systemctl status releves-chantier`, `sudo journalctl -u releves-chantier -n 50`,
  `sudo systemctl start releves-chantier-maj` (forcer la mise à jour), `systemctl list-timers | grep releves`.

## Points importants
- Rôles (Réglages de l'appli, bas de la colonne) : « Tablette principale » envoie chaque modification au serveur
  (file d'attente hors ligne `outbox` dans IndexedDB) ; « Consultation » lit le serveur, rien n'est modifiable.
- Le dossier d'exemple (M. Hoarau) n'est jamais envoyé au serveur.
- iPad : cases de texte verrouillées tant qu'on ne les touche pas (bloque l'écriture manuscrite du Pencil),
  pavé numérique maison pour téléphone, code postal et mesures en mm.
- Dessin : traits éditables, aimants (sommets, horizontal/vertical à 5°, même longueur), cotes posées en touchant un trait,
  zoom 2 doigts, plein écran qui agrandit la feuille aux proportions de l'écran.
- Exports : PDF (impression A4), JSON (réimportable), étiquette contact 62 × 60 mm.
