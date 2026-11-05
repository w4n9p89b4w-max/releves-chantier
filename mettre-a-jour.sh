#!/usr/bin/env bash
# Relevés Chantier : récupère la dernière version sur GitHub (lancé par le Pi toutes les 5 minutes).
# Ne touche jamais aux données (releves.db n'est pas suivi par git).
set -u
DOSSIER="$(cd "$(dirname "$0")" && pwd)"
U="${RELEVES_USER:-$(stat -c %U "$DOSSIER")}"
[ -n "${NODE_BIN_DIR:-}" ] && export PATH="$NODE_BIN_DIR:$PATH"
cd "$DOSSIER" || exit 0

g() { sudo -u "$U" git -C "$DOSSIER" "$@"; }

g fetch -q origin main 2>/dev/null || exit 0      # pas de réseau : on réessaiera
AVANT="$(g rev-parse HEAD)"
APRES="$(g rev-parse origin/main)"
[ "$AVANT" = "$APRES" ] && exit 0

MODULES="$(g diff --name-only "$AVANT" "$APRES" -- package.json package-lock.json)"
g reset -q --hard origin/main
if [ -n "$MODULES" ]; then
  sudo -u "$U" env PATH="$PATH" npm --prefix "$DOSSIER" install --omit=dev --no-audit --no-fund
fi
systemctl restart releves-chantier.service
echo "Relevés Chantier mis à jour : ${AVANT:0:7} -> ${APRES:0:7}"
