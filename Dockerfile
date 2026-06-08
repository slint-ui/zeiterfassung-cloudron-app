# ---------------------------------------------------------------------------
# Builder: clone the slint-ui fork at a pinned ref and build the fat jar.
# Override the ref at build time:
#     cloudron build --build-arg ZE_REF=<sha-or-branch-or-tag>
# ---------------------------------------------------------------------------
FROM eclipse-temurin:25-jdk-noble AS builder

ARG ZE_REPO=https://github.com/slint-ui/zeiterfassung.git
ARG ZE_REF=main
# ZE_SHA is updated automatically by CI to the current HEAD SHA of ZE_REF.
# Changing it busts Docker's layer cache so the git fetch always re-runs.
# Pass --build-arg ZE_SHA=$(git rev-parse HEAD) when building manually.
ARG ZE_SHA=19fa9a04bc1542dcd7d66d9b3ae24a632d5ac8f2
# Optional: GitHub token for private repos. Pass with --build-arg GH_TOKEN=ghp_xxx
ARG GH_TOKEN=

ENV MAVEN_OPTS="-Dmaven.repo.local=/root/.m2/repository -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN if [ -n "${GH_TOKEN}" ]; then \
      REPO_WITH_AUTH=$(echo "${ZE_REPO}" | sed "s|https://|https://${GH_TOKEN}@|"); \
    else \
      REPO_WITH_AUTH="${ZE_REPO}"; \
    fi \
 && echo "Fetching ${ZE_REPO}@${ZE_REF} (sha: ${ZE_SHA})" \
 && git init . \
 && git remote add origin "${REPO_WITH_AUTH}" \
 && git -c protocol.version=2 fetch --depth 1 origin "${ZE_REF}" \
 && git checkout --detach FETCH_HEAD \
 && git rev-parse HEAD > /build/.ze-commit

RUN ./mvnw -B -ntp -DskipTests clean package \
 && cp target/zeiterfassung-*.jar /tmp/zeiterfassung.jar

# ---------------------------------------------------------------------------
# Runtime: Cloudron base + Temurin JDK 25
# ---------------------------------------------------------------------------
FROM cloudron/base:5.0.0

ENV JAVA_HOME=/opt/jdk-25 \
    PATH=/opt/jdk-25/bin:$PATH

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) temurin_arch=x64 ;; \
      arm64) temurin_arch=aarch64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_${temurin_arch}_linux_hotspot_25.0.3_9.tar.gz"; \
    curl -fsSL "$url" -o /tmp/jdk.tar.gz; \
    mkdir -p /opt/jdk-25; \
    tar -xzf /tmp/jdk.tar.gz -C /opt/jdk-25 --strip-components=1; \
    rm /tmp/jdk.tar.gz; \
    java -version

RUN mkdir -p /app/code /app/data
WORKDIR /app/code

COPY --from=builder /tmp/zeiterfassung.jar /app/code/zeiterfassung.jar
COPY --from=builder /build/.ze-commit /app/code/.ze-commit
COPY cloudron/start.sh /app/code/start.sh
# GitHub App private key — written by CI from the GH_APP_PRIVATE_KEY repo secret.
# Empty file if secret is not set; start.sh checks for non-empty before using it.
COPY cloudron/github-app-private-key.pem /app/code/github-app-private-key.pem
RUN chmod +x /app/code/start.sh && chmod 600 /app/code/github-app-private-key.pem

EXPOSE 8080

CMD ["/app/code/start.sh"]
