## Overview

Zeiterfassung is an open-source web application for employee time tracking. It provides:

- Daily time entry with start/end times or duration
- Weekly and per-user time reports
- Internal and customer project tagging with reference fields
- GitHub activity digest — shows each developer's GitHub activity for the day as a reminder when logging time
- Overtime tracking
- Multi-tenant support

## On Cloudron

This package wires Zeiterfassung up to Cloudron's built-in services:

- **PostgreSQL** is provisioned automatically and used for all application data.
- **Single Sign-On** is handled through Cloudron's OIDC provider. Users log in with their Cloudron account.
- **Roles** are managed entirely inside the app — no Cloudron group setup required. The first user to log in is automatically promoted to admin (permission to manage all other users' roles). They can then assign roles to other users from the user management page.
- **Email** notifications are sent through Cloudron's SMTP relay.
- **Backups** of the database and `/app/data` are taken by Cloudron on the schedule you configure.

## GitHub Activity Integration (optional)

Set `GITHUB_TOKEN` (a PAT with `read:org` and `repo` scopes) and `GITHUB_ORG` in the app's environment variables. Users can then link their GitHub username on their profile page, and will see their previous day's GitHub activity alongside the time entry form as a memory aid.
