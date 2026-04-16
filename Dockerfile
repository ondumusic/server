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

ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.4
ARG NODEJS_VERSION=24
ARG DEBIAN_VERSION=trixie-20260223-slim

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
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"

# Install software and configure locale
RUN apt-get update \
  && apt-get install --fix-missing -y --no-install-recommends \
    libstdc++6 openssl libncurses6 locales \
    ca-certificates ffmpeg \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man


# Copy the compiled application
WORKDIR "/app"
RUN chown nobody /app
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/music_box ./

USER nobody
CMD ["/app/bin/server"]
