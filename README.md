# zeiterfassung-cloudron-app

Cloudron packaging for [Zeiterfassung](https://github.com/urlaubsverwaltung/zeiterfassung) — the Slint fork with customer project tracking and GitHub activity integration.

## Build & deploy

CI builds the image with plain Docker (no Cloudron build service), pushes it to
the private registry `registry.slint.dev`, and repoints the app at it with
`cloudron update --image`. The box pulls the runtime image from the registry;
`cloudron update` reads `CloudronManifest.json` from this repo.

```
①  CI: docker buildx --platform linux/amd64 --push  →  registry.slint.dev/zeiterfassung:<tag>
②  cloudron update --app zeit.slint.dev --image registry.slint.dev/zeiterfassung:<tag>
```

### Normal path (GitHub Actions)

Push to `master` (or run the **Build & Deploy to Cloudron** workflow) — see
[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml). The image is built
on a native amd64 runner from the Dockerfile, which clones the upstream Slint fork
at the pinned `ZE_SHA`. To build a newer upstream commit, bump `ARG ZE_SHA` in the
Dockerfile and push.

Required repository **secrets**: `CLOUDRON_TOKEN`, `REGISTRY_USERNAME`,
`REGISTRY_PASSWORD`. Required **variables**: `GH_APP_ID`, `GH_ORGANIZATION`.

**One-time box setup** so Cloudron can *pull* the private image: `my.slint.dev`
→ Settings → Private Docker Registry → add `registry.slint.dev` with credentials.

### Manual / local build

Cloudron runs `linux/amd64`, so on Apple Silicon you must cross-build under QEMU
(slow — prefer CI). `--server`/`--token` are global flags (before the subcommand);
`cloudron login` caches them.

```sh
cloudron login my.slint.dev
docker login registry.slint.dev
docker buildx build --platform linux/amd64 \
  -t registry.slint.dev/zeiterfassung:<tag> --push .
cloudron update --app zeit.slint.dev --image registry.slint.dev/zeiterfassung:<tag>
```

### Registry garbage collection

Untagged blobs accumulate in the registry. To reclaim space, open the **registry**
app's Web Terminal on Cloudron and run:

```sh
/usr/local/bin/gosu cloudron:cloudron /app/code/registry garbage-collect --delete-untagged /app/data/config.yml
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
