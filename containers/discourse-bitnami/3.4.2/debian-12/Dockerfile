# syntax=docker/dockerfile:1
#
# Discourse with its plugins and JavaScript assets already built.
#
# Unlike the other images here this is a thin derivative of the upstream Bitnami
# image rather than a from-scratch build, on purpose: the consuming Helm release
# depends on the Bitnami directory layout, startup scripts and environment
# contract. The only thing this image changes is *when* work happens.
#
# Upstream needs four to six minutes before Passenger binds its port, and nearly
# all of it is `rake assets:precompile` running on every single pod start. That
# delay is not just slow deploys: while a pod is compiling it burns CPU, which
# pollutes the very metric an HPA scales on.
#
# Discourse's own assets.rake skips the only database-dependent step - CSS - when
# SKIP_DB_AND_REDIS=1, so the JavaScript build runs happily with no database and
# no Redis. That is what makes baking it here possible at all. CSS still compiles
# at container start, where the database exists; measured at ~15 seconds against
# the ~4 minutes this removes.

ARG BASE_IMAGE=docker.io/bitnamilegacy/discourse
ARG BASE_TAG=3.4.2-debian-12-r5

FROM ${BASE_IMAGE}:${BASE_TAG}

# Pinned deliberately. `rake plugin:install` clones HEAD, which today resolves to
# a July 2025 commit while the forum runs a February 2024 one - baking it
# unpinned would smuggle a plugin upgrade into an unrelated change.
ARG ADPLUGIN_REPOSITORY=https://github.com/discourse/discourse-adplugin
ARG ADPLUGIN_REF=062efc8a547c19474eaeefae464837d63a5e5fb3

ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="discourse-bitnami" \
      org.opencontainers.image.description="Bitnami Discourse with plugins and JS assets prebuilt" \
      org.opencontainers.image.base.name="${BASE_IMAGE}:${BASE_TAG}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

USER root
WORKDIR /opt/bitnami/discourse
ENV PATH="/opt/bitnami/ruby/bin:${PATH}" \
    RAILS_ENV=production

RUN git clone "${ADPLUGIN_REPOSITORY}" plugins/discourse-adplugin \
    && git -C plugins/discourse-adplugin checkout --quiet "${ADPLUGIN_REF}"

RUN SKIP_DB_AND_REDIS=1 bundle exec rake assets:precompile

# Tells the Bitnami startup script to compile CSS only. The JavaScript build it
# would otherwise run is the one baked above.
ENV DISCOURSE_PRECOMPILE_ASSETS=no

USER 1001
