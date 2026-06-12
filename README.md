# Portable Kafka Connect Console

Petite console statique pour piloter des connecteurs Kafka Connect depuis une machine Windows de rebond.

## Mode direct

Ouvre `connectors.html` dans un navigateur, puis renseigne l'URL Kafka Connect de l'environnement:

- DEV: `http://host-dev:8083`
- UAT: `https://...`
- STA: `https://...`
- PROD: `https://...`

Limite: le mode direct depend des headers CORS exposes par Kafka Connect ou par le reverse proxy.

## Mode proxy Windows

Si le navigateur bloque les appels avec une erreur CORS, utilise le proxy local PowerShell:

```powershell
cd C:\chemin\vers\portable-connectors-console
copy connectors-env.example.json connectors-env.json
notepad connectors-env.json
.\start-connectors-console.ps1 -Port 8095
```

Ou plus simple: double-clique sur `start-connectors-console.bat`.

Puis ouvre:

```text
http://localhost:8095/connectors.html
```

Dans la page:

- selectionne l'environnement
- selectionne `Proxy transparent`
- laisse l'URL reelle visible dans le champ base URL si tu veux, mais les appels partiront automatiquement via `/proxy/<env>`

Le navigateur appelle `localhost`, et le script PowerShell relaie vers les vrais endpoints Kafka Connect.

Important: si tu ouvres `connectors.html` en `file://`, les endpoints DEV/UAT/STA/PROD peuvent etre bloques par CORS.
Dans ce cas il faut passer par `http://localhost:8095/connectors.html` et utiliser le mode `Proxy transparent`.

## Actions disponibles

- lister les connecteurs et leurs tasks
- filtrer par nom/topic/classe/etat
- consulter la config en masquant les secrets
- restart connector
- restart failed tasks
- restart task
- pause/resume
- delete avec confirmation par nom exact
