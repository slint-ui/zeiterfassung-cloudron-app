#!/bin/bash
set -euo pipefail

echo "==> Starting Zeiterfassung on Cloudron"

# ---------------------------------------------------------------------------
# Persistent data directories
# ---------------------------------------------------------------------------
mkdir -p /app/data/logs
chown -R cloudron:cloudron /app/data

# ---------------------------------------------------------------------------
# Database (Cloudron postgresql addon)
# ---------------------------------------------------------------------------
export SPRING_DATASOURCE_URL="jdbc:postgresql://${CLOUDRON_POSTGRESQL_HOST}:${CLOUDRON_POSTGRESQL_PORT}/${CLOUDRON_POSTGRESQL_DATABASE}"
export SPRING_DATASOURCE_USERNAME="${CLOUDRON_POSTGRESQL_USERNAME}"
export SPRING_DATASOURCE_PASSWORD="${CLOUDRON_POSTGRESQL_PASSWORD}"

# ---------------------------------------------------------------------------
# SMTP (Cloudron sendmail addon)
# ---------------------------------------------------------------------------
export SPRING_MAIL_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
export SPRING_MAIL_PORT="${CLOUDRON_MAIL_SMTP_PORT}"
export SPRING_MAIL_USERNAME="${CLOUDRON_MAIL_SMTP_USERNAME}"
export SPRING_MAIL_PASSWORD="${CLOUDRON_MAIL_SMTP_PASSWORD}"
export SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
export SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true

export ZEITERFASSUNG_MAIL_FROM="${CLOUDRON_MAIL_FROM}"
export ZEITERFASSUNG_MAIL_FROMDISPLAYNAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Zeiterfassung}"
export ZEITERFASSUNG_MAIL_REPLYTO="${CLOUDRON_MAIL_FROM}"
export ZEITERFASSUNG_MAIL_REPLYTODISPLAYNAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Zeiterfassung}"

# ---------------------------------------------------------------------------
# OIDC (Cloudron oidc addon)
#
# Cloudron provides:
#   CLOUDRON_OIDC_ISSUER        — issuer URI (Spring will discover endpoints)
#   CLOUDRON_OIDC_CLIENT_ID     — OAuth2 client id
#   CLOUDRON_OIDC_CLIENT_SECRET — OAuth2 client secret
#
# Roles are managed entirely inside the app — no Cloudron groups needed.
# The first user to log in is automatically granted ZEITERFASSUNG_PERMISSIONS_EDIT_ALL,
# which lets them assign roles to all other users from the user management page.
# Subsequent users log in with basic access (ZEITERFASSUNG_USER) only.
# ---------------------------------------------------------------------------
export SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_ID="${CLOUDRON_OIDC_CLIENT_ID}"
export SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_SECRET="${CLOUDRON_OIDC_CLIENT_SECRET}"
export SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_SCOPE="openid,profile,email"
export SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_PROVIDER="default"
export SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_DEFAULT_ISSUER_URI="${CLOUDRON_OIDC_ISSUER}"

# Disable the OIDC claim-based authority check — roles are stored in the app's
# own database and managed via the user management UI, not via OIDC claims.
export ZEITERFASSUNG_SECURITY_OIDC_CLAIM_MAPPERS_AUTHORITY_CHECK_ENABLED=false

# Redirect to the OAuth2 login page when unauthenticated
export ZEITERFASSUNG_SECURITY_OIDC_LOGIN_FORM_URL="/oauth2/authorization/default"

# Post-logout: return to the app origin so Cloudron can handle the session end
export ZEITERFASSUNG_SECURITY_OIDC_POST_LOGOUT_REDIRECT_URI="${CLOUDRON_APP_ORIGIN}"

# ---------------------------------------------------------------------------
# Urlaubsverwaltung absence sync (optional)
#
# Set UV_URL, UV_API_USERNAME, UV_API_PASSWORD in the Cloudron app's
# environment config to enable daily absence syncing from Urlaubsverwaltung.
#
# UV_API_USERNAME/PASSWORD must belong to a UV account with the Office role.
# Absences are matched to Zeiterfassung users by email address (both come
# from the same Cloudron OIDC provider, so emails will always match).
# ---------------------------------------------------------------------------
export ZEITERFASSUNG_INTEGRATION_URLAUBSVERWALTUNG_API_URL="${UV_URL:-}"
export ZEITERFASSUNG_INTEGRATION_URLAUBSVERWALTUNG_API_USERNAME="${UV_API_USERNAME:-}"
export ZEITERFASSUNG_INTEGRATION_URLAUBSVERWALTUNG_API_PASSWORD="${UV_API_PASSWORD:-}"

# ---------------------------------------------------------------------------
# GitHub integration (optional — for the activity digest bot)
# Set GITHUB_TOKEN and GITHUB_ORG in the Cloudron app's environment config.
# ---------------------------------------------------------------------------
export ZEITERFASSUNG_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
export ZEITERFASSUNG_GITHUB_ORG="${GITHUB_ORG:-}"

# ---------------------------------------------------------------------------
# GitHub App integration (optional — for the automated activity sync)
#
# Set the following in Cloudron → App Settings → Environment Variables:
#
#   GITHUB_APP_ID          — numeric App ID from your GitHub App's settings page
#   GITHUB_APP_PRIVATE_KEY — full contents of the downloaded .pem file,
#                            base64-encoded (run: base64 -w0 private-key.pem)
#   GITHUB_ORGANIZATION    — your GitHub organization login (e.g. "slint-ui")
#
# The private key is decoded from the env var and written to persistent storage
# on each startup so no file upload or SSH access is needed.
#
# Spring Boot's relaxed binding maps these env vars automatically:
#   GITHUB_APP_ID            → github.app.id
#   GITHUB_APP_PRIVATE_KEY_PATH → github.app.private-key-path
#   GITHUB_ORGANIZATION      → github.organization
# ---------------------------------------------------------------------------
if [ -n "${GITHUB_APP_PRIVATE_KEY:-}" ]; then
  echo "$GITHUB_APP_PRIVATE_KEY" | base64 -d > /app/data/github-app-private-key.pem
  chmod 600 /app/data/github-app-private-key.pem
  export GITHUB_APP_PRIVATE_KEY_PATH=/app/data/github-app-private-key.pem
  echo "==> GitHub App private key written to /app/data/github-app-private-key.pem"
fi

# ---------------------------------------------------------------------------
# Server and JVM tuning
# ---------------------------------------------------------------------------
export LOGGING_FILE_NAME="/app/data/logs/zeiterfassung.log"
export SERVER_PORT=8080

# Enable Kubernetes-style health probes (required for Cloudron health check)
export MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true

# Trust X-Forwarded-* headers from Cloudron's reverse proxy
export SERVER_FORWARD_HEADERS_STRATEGY=framework

# Tune JVM for the manifest's memory limit (1.5 GB)
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"

echo "==> Launching JVM"
exec /usr/local/bin/gosu cloudron:cloudron java -jar /app/code/zeiterfassung.jar
