#kasm_user
#password
ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-noble"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG

USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
WORKDIR $HOME

### Envrionment config 
ENV DEBIAN_FRONTEND=noninteractive \
    SKIP_CLEAN=true \
    KASM_RX_HOME=$STARTUPDIR/kasmrx \
    DONT_PROMPT_WSL_INSTALL="No_Prompt_please" \
    INST_DIR=$STARTUPDIR/install \
    INST_SCRIPTS="/ubuntu/install/tools/install_tools_deluxe.sh \
                  /ubuntu/install/misc/install_tools.sh \
                  /ubuntu/install/firefox/install_firefox.sh \
                  /ubuntu/install/vs_code/install_vs_code.sh \
                  /ubuntu/install/gamepad_utils/install_gamepad_utils.sh \
                  /ubuntu/install/cleanup/cleanup.sh"

# Copy install scripts
COPY ./src/ $INST_DIR

# Run standard installations
RUN \
  for SCRIPT in $INST_SCRIPTS; do \
    bash ${INST_DIR}${SCRIPT} || exit 1; \
  done
           
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

# Install Discord from package
RUN wget -O discord.deb "https://discord.com/api/download?platform=linux&format=deb" \
    && apt-get install -y ./discord.deb \
    && rm discord.deb

# Install Vesktop from package
RUN wget -O vesktop.deb "https://github.com/Vencord/Vesktop/releases/download/v1.5.5/vesktop_1.5.5_amd64.deb" \
    && apt-get install -y ./vesktop.deb \
    && rm vesktop.deb

# Install VLC from package
RUN apt-get install -y vlc

# Install Python and pip for Discord Rich Presence Plex
RUN apt-get install -y python3 python3-pip python3-venv git

# Install Discord Rich Presence Plex dependencies first
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed \
    PlexAPI==4.17.1 \
    requests==2.32.5 \
    websocket-client==1.8.0 \
    PyYAML==6.0.2 \
    pillow==11.3.0

# Install Discord Rich Presence Plex from GitHub
RUN git clone https://github.com/phin05/discord-rich-presence-plex.git /opt/discord-rich-presence-plex

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
RUN wget https://github.com/SpacingBat3/WebCord/releases/download/v4.10.3/webcord_4.10.3_amd64.deb \
    && apt-get install -y ./webcord_4.10.3_amd64.deb \
    && rm webcord_4.10.3_amd64.deb

# Create Desktop directory for kasm-user
RUN mkdir -p /home/kasm-user/Desktop/

# Create desktop shortcuts for VLC, Vesktop, WebCord, and Discord (Firefox desktop shortcut is created by install script)
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Vesktop\nComment=Vencord Vesktop\nExec=/usr/bin/vesktop --no-sandbox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=AudioVideo;\n' > $HOME/Desktop/vesktop.desktop \
    && chmod +x $HOME/Desktop/vesktop.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=Discord\nComment=Discord\nExec=/usr/bin/discord --no-sandbox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/discord.desktop \
    && chmod +x $HOME/Desktop/discord.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=VLC Media Player\nComment=Multimedia player\nExec=/usr/bin/vlc\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/vlc.png\nType=Application\nCategories=AudioVideo;Player;\n' > $HOME/Desktop/vlc.desktop \
    && chmod +x $HOME/Desktop/vlc.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=WebCord\nComment=WebCord Client\nExec=webcord --no-sandbox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/webcord.desktop \
    && chmod +x $HOME/Desktop/webcord.desktop

# Create Downloads directory for kasm-user
RUN mkdir -p /home/kasm-user/Downloads/ \
    && mkdir -p /home/kasm-default-profile/Downloads/

# Copy the default profile to the home directory
RUN cp -rp /home/kasm-default-profile/. /home/kasm-user/ --no-preserve=mode

# Cleanup
RUN apt-get autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* \
    && chmod -R 755 /home/kasm-default-profile \
    && rm -rf $INST_DIR

COPY ./vnc_startup.sh $STARTUPDIR/vnc_startup.sh
COPY ./drpp_startup.sh $STARTUPDIR/drpp_startup.sh
COPY ./drpp_config_template.yaml $STARTUPDIR/drpp_config_template.yaml

RUN chmod +x $STARTUPDIR/drpp_startup.sh

# Userspace Runtime
# Userspace Runtime
ENV HOME /home/kasm-user
WORKDIR $HOME

RUN mkdir -p $HOME && chown -R 1000:0 $HOME
RUN mkdir -p /run/user/1000 /tmp/runtime-kasm-user && chown -R 1000:0 /run/user/1000 /tmp/runtime-kasm-user

# Set environment variables
ENV XDG_DATA_DIRS=/app/data:/usr/local/share:/usr/share

#ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
ENV XDG_RUNTIME_DIR="/tmp/runtime-kasm-user"

# PipeWire environment variables
ENV PULSE_RUNTIME_PATH="/tmp/runtime-kasm-user/pulse"
ENV PIPEWIRE_RUNTIME_DIR="/tmp/runtime-kasm-user"
ENV PIPEWIRE_LATENCY="512/48000"

# Enable PipeWire by default and set additional audio environment variables
ENV START_PIPEWIRE=1
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
RUN mkdir -p /run/dbus && chown -R 1000:0 /run/dbus
RUN mkdir -p /dev/snd && chown -R 1000:0 /dev/snd
RUN $STARTUPDIR/set_user_permission.sh $HOME

# Create Firefox policies directory and add configuration for screen sharing
RUN mkdir -p /usr/lib/firefox/distribution \
    && echo '{\n  "policies": {\n    "Permissions": {\n      "Camera": {\n        "Allow": ["https://*", "http://*"]\n      },\n      "Microphone": {\n        "Allow": ["https://*", "http://*"]\n      }\n    },\n    "Preferences": {\n      "media.navigator.mediadatadecoder_vpx_enabled": true,\n      "media.peerconnection.enabled": true,\n      "media.getusermedia.screensharing.enabled": true,\n      "media.getusermedia.browser.enabled": true,\n      "media.getusermedia.audiocapture.enabled": true,\n      "media.navigator.permission.disabled": true\n    }\n  }\n}' > /usr/lib/firefox/distribution/policies.json

# Create Firefox user preferences for pipewire support
RUN mkdir -p /home/kasm-user/.mozilla/firefox \
    && mkdir -p /home/kasm-default-profile/.mozilla/firefox \
    && echo 'user_pref("media.cubeb.backend", "pipewire");\nuser_pref("media.cubeb.sandbox", false);\nuser_pref("media.getusermedia.screensharing.enabled", true);\nuser_pref("media.getusermedia.browser.enabled", true);\nuser_pref("media.getusermedia.audiocapture.enabled", true);\nuser_pref("media.navigator.permission.disabled", true);\nuser_pref("media.autoplay.default", 0);' > /home/kasm-user/.mozilla/firefox/user.js \
    && cp /home/kasm-user/.mozilla/firefox/user.js /home/kasm-default-profile/.mozilla/firefox/user.js

USER 1000