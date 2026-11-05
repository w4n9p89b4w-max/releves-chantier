# Relevés Chantier

Appli de visite de chantier (iPad) : coordonnées client, détail chantier (toiture, portail),
dessin coté, photos et fichiers, remarques, rapport PDF et étiquette contact.

## Installation sur le Raspberry (une seule fois, depuis la maison)

1. Ouvrir un terminal sur le Pi (comme pour le site budget : `ssh` depuis le Mac).
2. Coller cette commande :

   ```bash
   curl -fsSL https://raw.githubusercontent.com/w4n9p89b4w-max/releves-chantier/main/installer-pi.sh | bash
   ```

3. Choisir un code d'accès (ou appuyer sur Entrée pour en créer un) et le noter : il est affiché à la fin.

Ensuite, chaque modification envoyée sur GitHub arrive toute seule sur le Pi en 5 minutes au plus.

## Adresse en ligne

Cloudflare › Zero Trust › Networks › Tunnels › le tunnel du Pi › Public Hostname › Add :
sous-domaine `releves`, domaine `fayetcardoso.fr`, service `HTTP`, URL `localhost:3010`.

## Régler les appareils

- **iPad** : ouvrir https://releves.fayetcardoso.fr dans Safari › Partager › « Sur l'écran d'accueil ».
  Dans l'appli : Réglages (en bas à gauche) › « Tablette principale » › code d'accès › Enregistrer.
- **Mac / PC** : même adresse (Chrome ou Edge : « Installer l'appli »). Réglages › « Consultation » › même code.

## Essayer sur ce PC

Double-cliquer sur `lancer.bat` (code de test : `code-de-test-local`).
