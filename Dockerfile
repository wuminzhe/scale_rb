FROM ruby:2.6-slim

WORKDIR /usr/src/scale-rb

COPY . .

RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install curl iptables build-essential \
    git wget jq vim make gcc nano tmux htop nvme-cli \
    pkg-config libssl-dev libleveldb-dev libgmp3-dev \
    tar clang bsdmainutils ncdu unzip llvm libudev-dev \
    make protobuf-compiler -y && \
  # install and configure rustup and minimal components
  curl -L "https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init" \
    -o rustup-init; \
  chmod +x rustup-init; \
  ./rustup-init -y --no-modify-path --profile minimal --default-toolchain stable; \
  echo 'export PATH="/usr/local/cargo/bin:$PATH"' >> "${HOME}/.bashrc" && \
  \. "${HOME}/.bashrc" && \
  \. "$HOME/.cargo/env" && \
  rustup toolchain install nightly && \
  rustup default nightly && \
  rustup update && \
  rustup update nightly && \
  rustup target add wasm32-unknown-unknown --toolchain nightly && \
  rustup show && \
  cargo --version && \
  gem install bundler:2.1.4 && \
  bundle install && \
  # install gem locally
  rake install:local

CMD tail -f /dev/null