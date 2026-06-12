# Portable Kafka Connect Console

Small static console to manage Kafka Connect connectors from a Windows jump box.

## Direct Mode

Open `connectors.html` in a browser, then fill in the Kafka Connect URL for the target environment:

- DEV: `http://host-dev:8083`
- UAT: `https://...`
- STA: `https://...`
- PROD: `https://...`

Limit: direct mode depends on the CORS headers exposed by Kafka Connect or by the reverse proxy.

## Windows Proxy Mode

If the browser blocks calls with a CORS error, use the local PowerShell proxy:

```powershell
cd C:\path\to\portable-connectors-console
copy connectors-env.example.json connectors-env.json
notepad connectors-env.json
.\start-connectors-console.ps1 -Port 8095
```

Or simply double-click `start-connectors-console.bat`.

Then open:

```text
http://localhost:8095/connectors.html
```

The page automatically loads `connectors-env.json` at startup when served by the local launcher.

In the page:

- select the environment
- select `Transparent proxy`
- the real URL from the file is shown in the base URL field, but calls are automatically sent through `/proxy/<env>`

The browser calls `localhost`, and the PowerShell script forwards requests to the real Kafka Connect endpoints.

Important: if you open `connectors.html` with `file://`, DEV/UAT/STA/PROD endpoints may be blocked by CORS.
In that case, use `http://localhost:8095/connectors.html` and select `Transparent proxy` mode.

## Available Actions

- list connectors and their tasks
- filter by name/topic/class/state
- inspect config with secrets masked
- view config as a key/value list or formatted JSON
- copy masked config as JSON
- restart connector
- restart failed tasks
- restart task
- pause/resume
- delete with exact-name confirmation
