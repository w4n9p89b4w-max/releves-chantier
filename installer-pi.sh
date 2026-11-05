#!/usr/bin/env bash
# =====================================================================
#  Relevés Chantier : installation sur le Raspberry (à lancer UNE fois)
#
#  Depuis un terminal connecté au Pi :
#    curl -fsSL https://raw.githubusercontent.com/w4n9p89b4w-max/releves-chantier/main/installer-pi.sh | bash
#
#  Ce que fait le script :
#   1. récupère l'appli depuis GitHub dans ~/releves-chantier
#   2. installe les modules
#   3. règle le code d'accès (demandé, ou créé au hasard)
#   4. crée le service « releves-chantier » (port 3010, démarre tout seul)
#   5. crée la mise à jour automatique : toutes les 5 minutes, le Pi
#      récupère la dernière version sur GitHub et redémarre si besoin
#  Il peut être relancé sans risque : les données et le code sont gardés.
# =====================================================================
set -euo pipefail

DEPOT="https://github.com/w4n9p89b4w-max/releves-chantier.git"
DOSSIER="$HOME/releves-chantier"
PORT=3010
ENVF=/etc/releves-chantier.env

echo
echo "=== Relevés Chantier : installation ==="

# Node.js (installé avec nvm sur ce Pi)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
NODE="$(command -v node || true)"
NPM="$(command -v npm || true)"
if [ -z "$NODE" ] || [ -z "$NPM" ]; then
  echo "Node.js est introuvable. Il faut le même Node que pour le site budget." >&2
  exit 1
fi
echo "Node : $("$NODE" -v) ($NODE)"

# 1. Récupérer l'appli
if [ -d "$DOSSIER/.git" ]; then
  echo "Mise à jour de $DOSSIER…"
  git -C "$DOSSIER" pull --ff-only
else
  echo "Téléchargement dans $DOSSIER…"
  git clone "$DEPOT" "$DOSSIER"
fi
cd "$DOSSIER"

# 2. Modules
echo "Installation des modules (1 à 3 minutes)…"
"$NPM" install --omit=dev --no-audit --no-fund

# 3. Code d'accès (gardé hors de GitHub, lisible seulement par root)
if sudo test -f "$ENVF"; then
  CODE="$(sudo sed -n 's/^RELEVES_TOKEN=//p' "$ENVF")"
  echo "Code d'accès déjà réglé : il est gardé."
else
  echo
  read -r -p "Choisis le code d'accès (12 caractères minimum, ou Entrée pour en créer un) : " CODE </dev/tty || CODE=""
  if [ -z "$CODE" ]; then
    CODE="$(tr -dc 'A-HJ-NP-Za-km-z2-9' </dev/urandom | head -c 16 || true)"
  fi
  if [ "${#CODE}" -lt 12 ]; then
    echo "Code trop court (12 caractères minimum). Relance le script." >&2
    exit 1
  fi
  printf 'PORT=%s\nRELEVES_TOKEN=%s\nRELEVES_DB=%s\n' "$PORT" "$CODE" "$DOSSIER/releves.db" | sudo tee "$ENVF" >/dev/null
  sudo chmod 600 "$ENVF"
fi

# 4. Service de l'appli
sudo tee /etc/systemd/system/releves-chantier.service >/dev/null <<EOF
[Unit]
Description=Releves Chantier (appli + synchronisation)
After=network.target

[Service]
User=$USER
WorkingDirectory=$DOSSIER
EnvironmentFile=$ENVF
ExecStart=$NODE server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5. Mise à jour automatique depuis GitHub
sudo tee /etc/systemd/system/releves-chantier-maj.service >/dev/null <<EOF
[Unit]
Description=Releves Chantier : recuperer la derniere version sur GitHub

[Service]
Type=oneshot
Environment=RELEVES_USER=$USER
Environment=NODE_BIN_DIR=$(dirname "$NODE")
ExecStart=/bin/bash $DOSSIER/mettre-a-jour.sh
EOF
sudo tee /etc/systemd/system/releves-chantier-maj.timer >/dev/null <<EOF
[Unit]
Description=Releves Chantier : verifier les mises a jour toutes les 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now releves-chantier.service releves-chantier-maj.timer
sudo systemctl restart releves-chantier.service
sleep 3

# Vérification
if curl -fsS -H "x-releves-token: $CODE" "http://127.0.0.1:$PORT/api/releves/status" >/dev/null; then
  ETAT="OK, l'appli répond sur le port $PORT"
else
  ETAT="PAS DE RÉPONSE : voir  sudo journalctl -u releves-chantier -n 50"
fi

echo
echo "================================================================"
echo " Relevés Chantier : $ETAT"
echo
echo " Code d'accès à saisir dans Réglages (iPad, Mac, PC) :"
echo "     $CODE"
echo
echo " Adresse : https://releves.fayetcardoso.fr"
echo " (nom d'hôte public du tunnel Cloudflare -> HTTP localhost:$PORT)"
echo
echo " Mises à jour : automatiques depuis GitHub toutes les 5 minutes."
echo " Données : $DOSSIER/releves.db (fichier à sauvegarder)"
echo "================================================================"
