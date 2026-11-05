@echo off
rem Double-clique pour essayer l'appli sur ce PC (donnees de test, rien n'est envoye en ligne).
rem Laisse cette fenetre ouverte tant que tu utilises l'appli.
cd /d "%~dp0"
title Releves Chantier - serveur local

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo  Node.js n'est pas installe sur cet ordinateur.
  echo  Installe la version "LTS" depuis https://nodejs.org puis relance ce fichier.
  start "" https://nodejs.org
  pause
  exit /b
)

where git >nul 2>nul
if not errorlevel 1 (
  echo Recuperation de la derniere version depuis GitHub...
  git pull --ff-only
)

node -e "require('better-sqlite3');require('express')" >nul 2>nul
if errorlevel 1 (
  echo Installation des modules pour cet ordinateur, patiente une minute...
  call npm install --omit=dev
)

set PORT=3010
set RELEVES_TOKEN=code-de-test-local
set RELEVES_DB=%~dp0releves-test.db
echo.
echo  Appli : http://localhost:3010
echo  Code d'acces de test (Reglages) : code-de-test-local
echo.
start "" http://localhost:3010
node server.js
pause
