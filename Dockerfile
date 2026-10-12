# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=bookworm-20250630-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.18.4-erlang-28.0.1-debian-bookworm-20250630-slim
#

ARG ELIXIR_VERSION=1.20.1
ARG OTP_VERSION=29.0.1
ARG NODEJS_VERSION=24
ARG DEBIAN_VERSION=trixie-20260610-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"
ARG NODE_BUILDER_IMAGE="docker.io/node:${NODEJS_VERSION}-slim"

########################################
# Step 1. Build assets
########################################
FROM --platform=$BUILDPLATFORM ${NODE_BUILDER_IMAGE} AS node-builder
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV NODE_OPTIONS="--max-old-space-size=2048"
ENV CI=true

# Prepare the directories
RUN mkdir -p /app/priv/static
RUN mkdir -p /app/assets
RUN mkdir -p /app/lib

# Enable corepack (for pnpm)
RUN corepack enable

# Copy lib (for elixir templates) and assets
COPY lib /app/lib
COPY assets /app/assets
WORKDIR /app/assets

# Install dependencies
RUN pnpm install --frozen-lockfile

# Generate router tree file
RUN pnpm run generate-routes

# Build the pnpm project
RUN pnpm tsc -b
RUN pnpm vite build --mode production


########################################
# Step 2. Build Elixir App
########################################
FROM ${BUILDER_IMAGE} AS builder
ENV MIX_ENV="prod"
ENV ERL_FLAGS="+JPperf true"

# Install software
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# Prepare mix
WORKDIR /app
RUN mix local.hex --force \
  && mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy configuration
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
COPY config/runtime.exs config/

# Compile dependencies
RUN mix deps.compile

# Copy files
COPY priv priv
COPY lib lib
COPY rel rel

# Copy compiled assets
COPY --from=node-builder --chown=nobody:root /app/priv/static priv/static/

# Compile and build the release
RUN mix compile
RUN mix phx.digest
RUN mix release


########################################
# Step 3. Build final image
########################################
FROM ${RUNNER_IMAGE} AS final

LABEL org.opencontainers.image.title="Ondu Server"
LABEL org.opencontainers.image.url="https://ondumusic.com"

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"

# Distribution isn't needed, so disable cookie generation
# (the generated cookie would be hardcoded in the resulting image, but since
# we dont need it we can just skip it altogether.)
ENV RELEASE_DISTRIBUTION="none"

# Everything that needs to be kept is stored in /data, mount a volume there.
ENV ONDU_DATABASE_PATH="/data/ondu.db"
ENV ONDU_ARTWORK_PATH="/data/artwork"
ENV ONDU_TRANSCODE_CACHE_PATH="/data/transcode-cache"

# The application files are read-only, the release writes tmp files to here.
ENV RELEASE_TMP="/tmp"

# Install software and configure locale (curl is used for the health check)
RUN apt-get update \
  && apt-get install --fix-missing -y --no-install-recommends \
    libstdc++6 openssl libncurses6 locales \
    ca-certificates ffmpeg curl \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Copy the compiled application, owned by root so it can't be modified when the
# application is compromised.
WORKDIR "/app"
COPY --from=builder /app/_build/${MIX_ENV}/rel/ondu ./

RUN mkdir /data && chown nobody /data
VOLUME ["/data"]

EXPOSE 4000
HEALTHCHECK --start-period=30s CMD curl --fail --silent http://localhost:4000/health || exit 1

USER nobody
CMD ["/app/bin/server"]
