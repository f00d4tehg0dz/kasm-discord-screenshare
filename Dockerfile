#kasm_user
#password
ARG BASE_TAG="1.17.0"
ARG BASE_IMAGE="core-ubuntu-noble"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG

USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
WORKDIR $HOME

### Environment config (Kasm standard)
ENV DEBIAN_FRONTEND=noninteractive \
    DISTRO=ubuntu \
    SKIP_CLEAN=true \
    KASM_RX_HOME=$STARTUPDIR/kasmrx \
    DONT_PROMPT_WSL_INSTALL="No_Prompt_please" \
    INST_DIR=$STARTUPDIR/install \
    INST_SCRIPTS="/ubuntu/install/tools/install_tools_deluxe.sh \
                  /ubuntu/install/misc/install_tools.sh \
                  /ubuntu/install/firefox/install_firefox.sh \
                  /ubuntu/install/vlc/install_vlc.sh \
                  /ubuntu/install/vs_code/install_vs_code.sh \
                  /ubuntu/install/gamepad_utils/install_gamepad_utils.sh \
                  /ubuntu/install/cleanup/cleanup.sh"

# Copy install scripts from workspaces-images (ubuntu and common)
COPY ./workspaces-images/src/ $INST_DIR

# Run standard installations
RUN \
  for SCRIPT in $INST_SCRIPTS; do \
    bash ${INST_DIR}${SCRIPT} || exit 1; \
  done

# Configure Firefox with Kasm optimizations
RUN if [ -f ${INST_DIR}/common/install/configure_firefox.sh ]; then \
      bash ${INST_DIR}/common/install/configure_firefox.sh || true; \
    fi
           
######### Customize Container Here ###########

# Install libva and VA-API driver
RUN apt-get update && apt-get install -y libva2 vainfo \
    && apt-get install -y libva-drm2 libva-x11-2 i965-va-driver vainfo \
    && apt-get install -y mesa-va-drivers gawk jq

# Install PipeWire and audio/video dependencies
RUN apt-get install -y \
    pipewire \
    pipewire-audio-client-libraries \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    libpipewire-0.3-0 \
    libpipewire-0.3-dev \
    libspa-0.2-modules \
    pulseaudio-utils \
    alsa-utils \
    gstreamer1.0-pipewire \
    libgstreamer1.0-0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    ffmpeg \
    v4l-utils

# Configure PipeWire to replace PulseAudio (without systemctl)
RUN mkdir -p /etc/pipewire/pipewire.conf.d \
    && echo 'context.exec = [ { path = "pactl" args = "info" } ]' > /etc/pipewire/pipewire.conf.d/10-gsettings.conf

# Install Vesktop from package (Discord and VLC are installed via scripts)
RUN wget -O vesktop.deb "https://github.com/Vencord/Vesktop/releases/download/v1.6.1/vesktop_1.6.1_amd64.deb" \
    && apt-get install -y ./vesktop.deb \
    && rm vesktop.deb

# Install Python and pip for Discord Rich Presence Plex
RUN apt-get install -y python3 python3-pip python3-venv git

# # Install Discord Rich Presence Plex dependencies first
# RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed \
#     PlexAPI==4.17.1 \
#     requests==2.32.5 \
#     websocket-client==1.8.0 \
#     PyYAML==6.0.2 \
#     pillow==11.3.0

# # Install Discord Rich Presence Plex from GitHub (optional, may fail if repo is unavailable)
# RUN git clone https://github.com/phin05/discord-rich-presence-plex.git /opt/discord-rich-presence-plex || true

# Copy the icons for VLC and Discords to Ubuntu-Mono-Dark icons theme
COPY /icons/firefox.png /usr/share/icons/ubuntu-mono-dark/apps/48/firefox.png
COPY /icons/discord.png /usr/share/icons/ubuntu-mono-dark/apps/48/discord.png
COPY /icons/vlc.png /usr/share/icons/ubuntu-mono-dark/apps/48/vlc.png
# Copy the icons for VLC and Discords to Ubuntu-Mono-Light icons theme
COPY /icons/firefox.png /usr/share/icons/ubuntu-mono-light/apps/48/firefox.png
COPY /icons/discord.png /usr/share/icons/ubuntu-mono-light/apps/48/discord.png
COPY /icons/vlc.png /usr/share/icons/ubuntu-mono-light/apps/48/vlc.png
# Copy the icons for VLC and Discords to the appropriate locations for HiColor icons theme
COPY /icons/firefox.png /usr/share/icons/hicolor/48x48/apps/firefox.png
COPY /icons/discord.png /usr/share/icons/hicolor/48x48/apps/discord.png
COPY /icons/vlc.png /usr/share/icons/hicolor/48x48/apps/vlc.png

# Download and install WebCord .deb package
RUN wget https://github.com/SpacingBat3/WebCord/releases/download/v4.12.1/webcord_4.12.1_amd64.deb \
    && apt-get install -y ./webcord_4.12.1_amd64.deb \
    && rm webcord_4.12.1_amd64.deb

# Create Desktop directory for kasm-user
RUN mkdir -p /home/kasm-user/Desktop/

# Create desktop shortcuts for Vesktop and WebCord (Discord via Flatpak, VLC/Firefox via install scripts)
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Vesktop\nComment=Vencord Vesktop\nExec=/usr/bin/vesktop --no-sandbox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=AudioVideo;\n' > $HOME/Desktop/vesktop.desktop \
    && chmod +x $HOME/Desktop/vesktop.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=WebCord\nComment=WebCord Client\nExec=webcord --no-sandbox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/webcord.desktop \
    && chmod +x $HOME/Desktop/webcord.desktop

# Install Flatpak, xdg-desktop-portal for sandboxed applications
RUN apt-get update && apt-get install -y \
    flatpak \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    fuse3 \
    bubblewrap \
    libfuse2

# Setup Flatpak directories and permissions
RUN mkdir -p /home/kasm-user/.local/share/flatpak \
    && mkdir -p /var/lib/flatpak \
    && chmod 755 /home/kasm-user/.local/share/flatpak \
    && chmod 755 /var/lib/flatpak

# Add Flathub repository and install Discord via Flatpak
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Discord from Flathub (system-wide installation)
RUN flatpak install -y --noninteractive --system flathub com.discordapp.Discord

# Configure Flatpak permissions for Discord (audio, IPC, etc.)
# Use --no-sandbox workaround for container environments
RUN mkdir -p /home/kasm-user/.local/share/flatpak/overrides \
    && echo '[Context]' > /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo 'filesystems=xdg-run/pipewire-0;/tmp/runtime-kasm-user;~/.config/discord;host;' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo 'sockets=pulseaudio;wayland;x11;' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo 'shared=network;ipc;' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo '[Session Bus Policy]' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo 'org.freedesktop.portal.*=talk' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo '[Environment]' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && echo 'ELECTRON_DISABLE_SANDBOX=1' >> /home/kasm-user/.local/share/flatpak/overrides/com.discordapp.Discord \
    && chown -R 1000:0 /home/kasm-user/.local/share/flatpak/overrides

# Create Discord launcher script that handles sandbox issues and stability in container environments
RUN mkdir -p /usr/local/bin \
    && printf '#!/bin/bash\n\
# Discord launcher for Kasm container environment\n\
# Disable Electron sandbox for container compatibility\n\
export ELECTRON_DISABLE_SANDBOX=1\n\
export ELECTRON_OZONE_PLATFORM_HINT=x11\n\
\n\
# Discord flags for container stability\n\
DISCORD_FLAGS="--no-sandbox"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-gpu-sandbox"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-seccomp-filter-sandbox"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-setuid-sandbox"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-dev-shm-usage"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-accelerated-2d-canvas"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-gpu-compositing"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --use-gl=swiftshader"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --ignore-gpu-blocklist"\n\
DISCORD_FLAGS="$DISCORD_FLAGS --disable-software-rasterizer"\n\
\n\
# Use .deb version\n\
if [ -x /usr/share/discord/Discord ]; then\n\
    echo "Launching Discord with stability flags..."\n\
    exec /usr/share/discord/Discord $DISCORD_FLAGS "$@"\n\
fi\n\
\n\
# Fallback to Flatpak if .deb not available and system bus exists\n\
if [ -S /run/dbus/system_bus_socket ] && flatpak info com.discordapp.Discord > /dev/null 2>&1; then\n\
    echo "Launching Discord via Flatpak..."\n\
    exec flatpak run --env=ELECTRON_DISABLE_SANDBOX=1 \\\n\
        --env=ELECTRON_NO_SANDBOX=1 \\\n\
        --command=/app/bin/Discord \\\n\
        com.discordapp.Discord $DISCORD_FLAGS "$@"\n\
fi\n\
\n\
echo "Error: Discord is not installed or cannot be launched"\n\
exit 1\n' > /usr/local/bin/discord-flatpak \
    && chmod +x /usr/local/bin/discord-flatpak

# Create Discord desktop shortcut using the wrapper script
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Discord\nComment=Discord - Chat for Communities and Friends\nExec=/usr/local/bin/discord-flatpak\nIcon=/var/lib/flatpak/app/com.discordapp.Discord/current/active/export/share/icons/hicolor/256x256/apps/com.discordapp.Discord.png\nType=Application\nCategories=Network;InstantMessaging;\nTerminal=false\n' > $HOME/Desktop/discord.desktop \
    && chmod +x $HOME/Desktop/discord.desktop

# Also apply the no-sandbox setting via flatpak override (system-wide)
RUN flatpak override --system --env=ELECTRON_DISABLE_SANDBOX=1 com.discordapp.Discord \
    && flatpak override --system --share=ipc --share=network com.discordapp.Discord \
    && flatpak override --system --filesystem=host com.discordapp.Discord || true

# Create symlink so /usr/bin/discord calls the Flatpak version
# Remove any existing discord binary and create symlink to our launcher
RUN rm -f /usr/bin/discord /usr/bin/Discord 2>/dev/null || true \
    && ln -sf /usr/local/bin/discord-flatpak /usr/bin/discord \
    && ln -sf /usr/local/bin/discord-flatpak /usr/bin/Discord

# Ensure Flatpak runtime directories exist with proper permissions
RUN mkdir -p /run/flatpak \
    && chmod 755 /run/flatpak \
    && mkdir -p /var/lib/flatpak/repo \
    && chmod -R 755 /var/lib/flatpak

# Verify Discord Flatpak installation
RUN flatpak list --app | grep -i discord || echo "Warning: Discord Flatpak may not be installed"

# Also install Discord .deb as fallback (in case Flatpak doesn't work in container)
RUN apt-get update \
    && curl -L -o /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb" \
    && apt-get install -y /tmp/discord.deb \
    && rm /tmp/discord.deb \
    && apt-get clean

# Configure Discord .deb version to use --no-sandbox by default
RUN mkdir -p /home/kasm-user/.config/discord \
    && echo '{"SKIP_HOST_UPDATE": true}' > /home/kasm-user/.config/discord/settings.json \
    && chown -R 1000:0 /home/kasm-user/.config/discord

# Modify Discord .desktop file to use --no-sandbox
RUN if [ -f /usr/share/applications/discord.desktop ]; then \
        sed -i 's|Exec=/usr/share/discord/Discord|Exec=/usr/share/discord/Discord --no-sandbox|g' /usr/share/applications/discord.desktop; \
    fi

# Create Downloads directory for kasm-user
RUN mkdir -p /home/kasm-user/Downloads/ \
    && mkdir -p /home/kasm-default-profile/Downloads/

# Copy the default profile to the home directory
RUN cp -rp /home/kasm-default-profile/. /home/kasm-user/ --no-preserve=mode

# Cleanup (preserve Flatpak)
RUN apt-get autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* \
    && chmod -R 755 /home/kasm-default-profile \
    && rm -rf $INST_DIR \
    && mkdir -p /tmp && chmod 1777 /tmp

COPY ./vnc_startup.sh $STARTUPDIR/vnc_startup.sh

# Copy custom startup script for Plex Discord integration
COPY ./src/custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Copy prebuilt Firefox extension
RUN mkdir -p /app/plex-firefox-ext
COPY ./plex-firefox-ext/plex-discord-control@local.xpi /app/plex-firefox-ext/

# Userspace Runtime
ENV HOME /home/kasm-user
WORKDIR $HOME

RUN mkdir -p $HOME && chown -R 1000:0 $HOME
RUN mkdir -p /run/user/1000 /tmp/runtime-kasm-user /tmp/pipewire-0 && \
    chown -R 1000:0 /run/user/1000 /tmp/runtime-kasm-user /tmp/pipewire-0 && \
    chmod 755 /tmp/runtime-kasm-user /tmp/pipewire-0 && \
    chmod 1777 /tmp

# Set environment variables for Flatpak and XDG
ENV XDG_DATA_DIRS=/app/data:/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:/home/kasm-user/.local/share/flatpak/exports/share

#ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
ENV XDG_RUNTIME_DIR="/tmp/runtime-kasm-user"

# PipeWire environment variables
ENV PULSE_RUNTIME_PATH="/tmp/runtime-kasm-user/pulse"
ENV PIPEWIRE_RUNTIME_DIR="/tmp/runtime-kasm-user"
ENV PIPEWIRE_LATENCY="512/48000"

# Disable early PipeWire startup - let the desktop environment handle it
ENV START_PIPEWIRE=0
ENV PULSE_SERVER="unix:/tmp/runtime-kasm-user/pulse/native"
ENV PIPEWIRE_DEBUG=3
ENV SPA_PLUGIN_DIR="/usr/lib/x86_64-linux-gnu/spa-0.2"
ENV PIPEWIRE_MODULE_DIR="/usr/lib/x86_64-linux-gnu/pipewire-0.3"

# Create PipeWire configuration directories
RUN mkdir -p /home/kasm-user/.config/pipewire \
    && mkdir -p /home/kasm-user/.config/wireplumber \
    && mkdir -p /home/kasm-default-profile/.config/pipewire \
    && mkdir -p /home/kasm-default-profile/.config/wireplumber \
    && mkdir -p /tmp/runtime-kasm-user/pulse \
    && chown -R 1000:0 /home/kasm-user/.config \
    && chown -R 1000:0 /home/kasm-default-profile/.config \
    && chown -R 1000:0 /tmp/runtime-kasm-user/pulse

# Set executable permission and allow launching for desktop files
RUN chmod +x /home/kasm-user/Desktop/*.desktop \
    && chmod +x /home/kasm-user/Desktop/*.desktop \
    && chmod 644 /home/kasm-user/Desktop/*.desktop

# Download pipewire-screenaudio Firefox add-on XPI file
RUN wget -O /home/kasm-user/Downloads/pipewire-screenaudio.xpi "https://addons.mozilla.org/firefox/downloads/latest/pipewire-screenaudio/addon-1564124-latest.xpi"
RUN cp /home/kasm-user/Downloads/pipewire-screenaudio.xpi /home/kasm-default-profile/Downloads/pipewire-screenaudio.xpi
RUN mkdir -p /run/dbus && chown -R 1000:0 /run/dbus && chmod 755 /run/dbus
RUN mkdir -p /dev/snd && chown -R 1000:0 /dev/snd

# Install WebSocket libraries with pinned versions for stability
# websockets 13.0+ changed the handler API - our code requires the new API
RUN pip3 install --no-cache-dir --break-system-packages websockets==13.0 aiohttp==3.9.1 aiofiles==23.2.1

RUN $STARTUPDIR/set_user_permission.sh $HOME

# Create Firefox policies directory and add configuration for screen sharing
RUN mkdir -p /usr/lib/firefox/distribution \
    && echo '{\n  "policies": {\n    "Permissions": {\n      "Camera": {\n        "Allow": ["https://*", "http://*"]\n      },\n      "Microphone": {\n        "Allow": ["https://*", "http://*"]\n      }\n    },\n    "Preferences": {\n      "media.navigator.mediadatadecoder_vpx_enabled": true,\n      "media.peerconnection.enabled": true,\n      "media.getusermedia.screensharing.enabled": true,\n      "media.getusermedia.browser.enabled": true,\n      "media.getusermedia.audiocapture.enabled": true,\n      "media.navigator.permission.disabled": true\n    }\n  }\n}' > /usr/lib/firefox/distribution/policies.json

# Create Firefox user preferences for pipewire support
RUN mkdir -p /home/kasm-user/.mozilla/firefox \
    && mkdir -p /home/kasm-default-profile/.mozilla/firefox \
    && echo 'user_pref("media.cubeb.backend", "pipewire");\nuser_pref("media.cubeb.sandbox", false);\nuser_pref("media.getusermedia.screensharing.enabled", true);\nuser_pref("media.getusermedia.browser.enabled", true);\nuser_pref("media.getusermedia.audiocapture.enabled", true);\nuser_pref("media.navigator.permission.disabled", true);\nuser_pref("media.autoplay.default", 0);' > /home/kasm-user/.mozilla/firefox/user.js \
    && cp /home/kasm-user/.mozilla/firefox/user.js /home/kasm-default-profile/.mozilla/firefox/user.js

# Copy plex-discord-server scripts AFTER all setup complete (to avoid being deleted by set_user_permission)
RUN mkdir -p /home/kasm-user/.local/bin
COPY plex-discord-server.py /home/kasm-user/.local/bin/plex-discord-server
COPY websocket-proxy.py /home/kasm-user/.local/bin/websocket-proxy
RUN chmod +x /home/kasm-user/.local/bin/plex-discord-server \
    && chmod +x /home/kasm-user/.local/bin/websocket-proxy \
    && chown -R 1000:0 /home/kasm-user/.local/bin

# Remove unwanted autostart services (Kasm optimization)
RUN rm -f \
    /etc/xdg/autostart/blueman.desktop \
    /etc/xdg/autostart/geoclue-demo-agent.desktop \
    /etc/xdg/autostart/gnome-keyring-pkcs11.desktop \
    /etc/xdg/autostart/gnome-keyring-secrets.desktop \
    /etc/xdg/autostart/gnome-keyring-ssh.desktop \
    /etc/xdg/autostart/light-locker.desktop \
    /etc/xdg/autostart/xfce4-power-manager.desktop \
    /etc/xdg/autostart/xfce4-screensaver.desktop \
    /etc/xdg/autostart/xscreensaver.desktop \
    2>/dev/null || true

EXPOSE 8764 8765 8766 8080

USER 1000

CMD ["--tail-log"]