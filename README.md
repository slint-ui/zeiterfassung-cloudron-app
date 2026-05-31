# zeiterfassung-cloudron-app

Cloudron packaging for [Zeiterfassung](https://github.com/urlaubsverwaltung/zeiterfassung) — the Slint fork with customer project tracking and GitHub activity integration.

## Build

```sh
cloudron build
```

To override the upstream ref being built:

```sh
cloudron build --build-arg ZE_REF=<commit-sha-or-branch-or-tag>
```

## Layout

- `CloudronManifest.json` — Cloudron app manifest
- `Dockerfile` — fetches Zeiterfassung sources from the slint-ui fork, builds the fat jar, assembles runtime image on `cloudron/base`
- `cloudron/start.sh` — entrypoint mapping Cloudron addon env vars to Spring Boot properties
- `cloudron/CHANGELOG` — Cloudron app changelog
- `cloudron/DESCRIPTION.md` — Cloudron app store description

## Cloudron groups → roles

Create these groups in the Cloudron admin panel:

| Cloudron group | Zeiterfassung role |
|---|---|
| `zeiterfassung_user` | Basic access (required) |
| `zeiterfassung_view_all` | View all users' time entries |
| `zeiterfassung_edit_all` | Edit all users' time entries |

## Urlaubsverwaltung absence sync (optional)

Zeiterfassung syncs approved absences from Urlaubsverwaltung every weekday at 06:00.
User matching is by email — since both apps use the same Cloudron OIDC provider, emails always match.
No data leaves your server (direct HTTP call between Cloudron apps).

Set in the Cloudron app environment:

| Variable | Description |
|---|---|
| `UV_URL` | Base URL of your UV instance, e.g. `https://ooo.slint.dev` |
| `UV_API_USERNAME` | UV account username with Office role |
| `UV_API_PASSWORD` | Password for that account |

Admins can also trigger a manual sync immediately via `POST /admin/uv-sync`.

## GitHub integration (optional)

Set in the Cloudron app environment:

| Variable | Description |
|---|---|
| `GITHUB_TOKEN` | PAT with `read:org` + `repo` scopes |
| `GITHUB_ORG` | Your GitHub organisation slug |

Users link their GitHub username on their profile page (`/profile`).
