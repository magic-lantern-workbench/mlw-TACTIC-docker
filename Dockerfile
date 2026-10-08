# syntax=docker/dockerfile:1

# ---- build stage: fetch TACTIC and build the Python venv (compilers stay here) ----
FROM python:3.11-slim AS build

ARG TACTIC_REPO=https://github.com/magic-lantern-workbench/TACTIC.git
# Branch or tag. Pin to a release tag for reproducible production builds.
ARG TACTIC_REF=magiclantern

RUN apt-get update && apt-get install -y --no-install-recommends \
        git gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${TACTIC_REF}" "${TACTIC_REPO}" /opt/tactic/tactic \
    && git -C /opt/tactic/tactic rev-parse HEAD > /opt/tactic/REVISION \
    && rm -rf /opt/tactic/tactic/.git

# Let the bind address come from TACTIC_BIND_HOST. Upstream derives it from <install><hostname>,
# which is also the public base URL, so it cannot be set to 0.0.0.0 there.
RUN sed -i "s|^    hostname = None\$|    server = server or os.environ.get('TACTIC_BIND_HOST', '')\n    hostname = None|" /opt/tactic/tactic/src/bin/startup.py \
    && grep -q TACTIC_BIND_HOST /opt/tactic/tactic/src/bin/startup.py

# CherryPy is the app server; pycryptodomex is required by the license check
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
        -r /opt/tactic/tactic/src/pyasm/requirements.txt \
        CherryPy pycryptodomex

# `tacticenv` is the install/data package that install.py normally copies into site-packages
RUN SP="$(/opt/venv/bin/python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
    && cp -r /opt/tactic/tactic/src/install/data "${SP}/tacticenv" \
    && printf "TACTIC_INSTALL_DIR = '/opt/tactic/tactic'\nTACTIC_SITE_DIR = ''\nTACTIC_DATA_DIR = '/opt/tactic/tactic_data'\n" \
        > "${SP}/tacticenv/tactic_paths.py"


# ---- runtime image for the TACTIC app ----
FROM python:3.11-slim AS tactic

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/venv/bin:$PATH \
    TACTIC_INSTALL_DIR=/opt/tactic/tactic \
    TACTIC_DATA_DIR=/opt/tactic/tactic_data \
    TACTIC_SITE_DIR= \
    TACTIC_TMP_DIR=/opt/tactic/tactic_temp \
    TACTIC_BIND_HOST=0.0.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        gettext-base postgresql-client tini \
        imagemagick ffmpeg ghostscript libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /usr/sbin/nologin tactic

COPY --from=build /opt/venv /opt/venv
COPY --from=build /opt/tactic /opt/tactic

COPY docker/tactic-conf.xml.template /opt/tactic/tactic-conf.xml.template
COPY docker/bootstrap_db.py /opt/tactic/bootstrap_db.py
COPY docker/bootstrap_project.py /opt/tactic/bootstrap_project.py
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p "${TACTIC_DATA_DIR}/assets" "${TACTIC_TMP_DIR}" \
    && chown -R tactic:tactic "${TACTIC_DATA_DIR}" "${TACTIC_TMP_DIR}"

USER tactic
WORKDIR /opt/tactic/tactic/src/bin
VOLUME ["/opt/tactic/tactic_data", "/opt/tactic/tactic_temp"]
EXPOSE 8081 8082 8083

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD python -c "import urllib.request as u; u.urlopen('http://127.0.0.1:8081/test', timeout=4)"

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
# monitor.py supervises several worker processes (ports from TACTIC_PORTS) and restarts them if they die
CMD ["python", "monitor.py"]


# ---- reverse proxy: TLS termination, static files, load balancing across workers ----
FROM nginx:stable-alpine AS proxy

COPY --from=build /opt/tactic/tactic/src/context /opt/tactic/tactic/src/context
COPY docker/nginx/ /etc/nginx/tactic/
COPY docker/nginx/10-select-config.sh /docker-entrypoint.d/10-select-config.sh
RUN chmod +x /docker-entrypoint.d/10-select-config.sh

EXPOSE 80 443
