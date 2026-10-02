FROM ghcr.io/charmbracelet/vhs

USER root
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      zsh git jq perl curl unzip fontconfig ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/local/share/fonts/symbols-nerd-font \
 && curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip \
      -o /tmp/symbols-nerd-font.zip \
 && unzip -q /tmp/symbols-nerd-font.zip -d /usr/local/share/fonts/symbols-nerd-font \
 && rm /tmp/symbols-nerd-font.zip \
 && fc-cache -f
ARG UID=1000
RUN useradd --uid "$UID" --create-home --home-dir /home/dev --shell /usr/bin/zsh dev \
 && install -d -o dev -g dev /home/dev/code /home/dev/remotes

WORKDIR /demo
COPY --chmod=755 entrypoint.sh setup-project.sh /demo/
COPY --chmod=755 stubs/glab stubs/git /demo/stubs/
ENTRYPOINT ["/demo/entrypoint.sh"]
