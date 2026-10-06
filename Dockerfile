# syntax=docker/dockerfile:1
FROM python:3.11-slim

ARG TACTIC_REPO=https://github.com/magic-lantern-workbench/TACTIC.git
ARG TACTIC_REF=5.0

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    TACTIC_INSTALL_DIR=/opt/tactic/tactic \
    TACTIC_DATA_DIR=/opt/tactic/tactic_data \
    TACTIC_SITE_DIR= \
    TACTIC_TMP_DIR=/opt/tactic/tactic_temp

RUN apt-get update && apt-get install -y --no-install-recommends \
        git gettext-base postgresql-client \
        gcc libc6-dev libpq-dev libxml2-dev libxslt1-dev \
        imagemagick ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash tactic \
    && mkdir -p /opt/tactic \
    && git clone --depth 1 --branch "${TACTIC_REF}" "${TACTIC_REPO}" "${TACTIC_INSTALL_DIR}" \
    && rm -rf "${TACTIC_INSTALL_DIR}/.git"

# Python dependencies (CherryPy is the app server; the repo's bundled copy is a fallback)
RUN pip install --no-cache-dir -r "${TACTIC_INSTALL_DIR}/src/pyasm/requirements.txt" \
        CherryPy pycryptodomex

# `tacticenv` is the install/data package that install.py normally copies into site-packages
RUN SP="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
    && cp -r "${TACTIC_INSTALL_DIR}/src/install/data" "${SP}/tacticenv" \
    && printf "TACTIC_INSTALL_DIR = '%s'\nTACTIC_SITE_DIR = ''\nTACTIC_DATA_DIR = '%s'\n" \
        "${TACTIC_INSTALL_DIR}" "${TACTIC_DATA_DIR}" > "${SP}/tacticenv/tactic_paths.py"

COPY docker/tactic-conf.xml.template /opt/tactic/tactic-conf.xml.template
COPY docker/bootstrap_db.py /opt/tactic/bootstrap_db.py
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p "${TACTIC_DATA_DIR}" "${TACTIC_TMP_DIR}" \
    && chown -R tactic:tactic /opt/tactic

USER tactic
WORKDIR /opt/tactic/tactic/src/bin
VOLUME ["/opt/tactic/tactic_data", "/opt/tactic/tactic_temp"]
EXPOSE 8081

ENTRYPOINT ["entrypoint.sh"]
CMD ["python", "startup.py", "8081", "--server", "0.0.0.0"]
