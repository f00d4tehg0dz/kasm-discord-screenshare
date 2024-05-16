ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-jammy"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG
USER root

#kasm_user
#password

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########

# Remove PulseAudio and Install PipeWire
RUN apt-get update -y \
    && apt-get remove -y pulseaudio \
    && rm /usr/share/alsa/alsa.conf.d/50-pulseaudio.conf \
    && apt-get install -y build-essential qtbase5-dev qtwebengine5-dev libkf5notifications-dev wget libkf5xmlgui-dev libkf5globalaccel-dev libpipewire-0.3 pipewire-media-session pipewire-audio-client-libraries libspa-0.2-jack libspa-0.2-bluetooth pulseaudio-module-bluetooth- debhelper-compat findutils git libasound2-dev libdbus-1-dev libglib2.0-dev libsbc-dev libsdl2-dev libudev-dev libv4l-dev libx11-dev ninja-build pkg-config python3-docutils python3-pip meson dbus-x11 rtkit fonts-liberation libu2f-udev xdg-utils unzip cmake \
    && ldconfig      

RUN apt-get install -y libva-dev libv4l-dev

# Install libva and VA-API driver
RUN apt-get update && apt-get install -y libva2 vainfo \
    && apt-get install -y libva-drm2 libva-x11-2 i965-va-driver vainfo \
    && apt-get install -y mesa-va-drivers gawk jq

# Download and setup virtmic
RUN curl -L "https://github.com/edisionnano/Screenshare-with-audio-on-Discord-with-Linux/blob/main/virtmic?raw=true" -o virtmic \
    && chmod +x virtmic

# Install Flatpak and add the Flathub repository
RUN apt-get update && apt-get install -y flatpak \
    && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Chromium
#RUN flatpak install -y flathub org.chromium.Chromium

# Install discord-screenaudio from Flathub
RUN flatpak install -y de.shorsh.discord-screenaudio

# Install Discord from Flathub
RUN flatpak install -y flathub com.discordapp.Discord

# Install VLC from Flathub
RUN flatpak install -y flathub org.videolan.VLC

# Install Firefox from tarball
RUN apt-get update \
    && wget -O firefox.tar.bz2 "https://download.mozilla.org/?product=firefox-latest&os=linux64" \
    && tar xjf firefox.tar.bz2 -C /opt \
    && ln -s /opt/firefox/firefox /usr/bin/firefox \
    && rm firefox.tar.bz2

# Copy the icons for Firefox, VLC and Discords to Ubuntu-Mono-Dark icons theme
COPY /icons/firefox.png /usr/share/icons/ubuntu-mono-dark/apps/48/firefox.png
COPY /icons/discord.png /usr/share/icons/ubuntu-mono-dark/apps/48/discord.png
COPY /icons/vlc.png /usr/share/icons/ubuntu-mono-dark/apps/48/vlc.png
# Copy the icons for Firefox, VLC and Discords to Ubuntu-Mono-Light icons theme
COPY /icons/firefox.png /usr/share/icons/ubuntu-mono-light/apps/48/firefox.png
COPY /icons/discord.png /usr/share/icons/ubuntu-mono-light/apps/48/discord.png
COPY /icons/vlc.png /usr/share/icons/ubuntu-mono-light/apps/48/vlc.png
# Copy the icons for Firefox, VLC and Discords to the appropriate locations for HiColor icons theme
COPY /icons/firefox.png /usr/share/icons/hicolor/48x48/apps/firefox.png
COPY /icons/discord.png /usr/share/icons/hicolor/48x48/apps/discord.png
COPY /icons/vlc.png /usr/share/icons/hicolor/48x48/apps/vlc.png
#COPY ./icons/chromium.png /usr/share/icons/ubuntu-mono-dark/apps/48/

# Create Desktop directory for kasm-user
RUN mkdir -p /home/kasm-user/Desktop/

# Create desktop shortcuts for Firefox, VLC, Discord Screen Audio, and Discord
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Discord Screen Audio\nComment=Flatpak Discord Screen Audio\nExec=/usr/bin/flatpak run --branch=stable --arch=x86_64 de.shorsh.discord-screenaudio "$@"\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=AudioVideo;\n' > $HOME/Desktop/discord-screenaudio.desktop \
    && chmod +x $HOME/Desktop/discord-screenaudio.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=Firefox\nComment=Mozilla Firefox\nExec=/opt/firefox/firefox\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/firefox.png\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/firefox.desktop \
    && chmod +x $HOME/Desktop/firefox.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=Discord\nComment=Discord\nExec=/var/lib/flatpak/app/com.discordapp.Discord/current/active/export/bin/com.discordapp.Discord\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/discord.png\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/discord.desktop \
    && chmod +x $HOME/Desktop/discord.desktop

RUN echo '[Desktop Entry]\nVersion=1.0\nName=VLC Media Player\nComment=Multimedia player\nExec=flatpak run org.videolan.VLC\nIcon=/usr/share/icons/ubuntu-mono-dark/apps/48/vlc.png\nType=Application\nCategories=AudioVideo;Player;\n' > $HOME/Desktop/vlc.desktop \
    && chmod +x $HOME/Desktop/vlc.desktop

# Set Firefox as the default web browser
RUN update-alternatives --install /usr/bin/x-www-browser x-www-browser /opt/firefox/firefox 200 \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /opt/firefox/firefox 200

# Create Downloads directory for kasm-user
RUN mkdir -p /home/kasm-user/Downloads/ \
    && mkdir -p /home/kasm-default-profile/Downloads/

# Copy the default profile to the home directory
RUN cp -rp /home/kasm-default-profile/. /home/kasm-user/ --no-preserve=mode

# https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.0.4/pipewire-1.0.4.tar
ARG PW_VERSION=1.0.4
ENV PW_ARCHIVE_URL="https://gitlab.freedesktop.org/pipewire/pipewire/-/archive"
ENV PW_TAR_FILE="pipewire-${PW_VERSION}.tar"
ENV PW_TAR_URL="${PW_ARCHIVE_URL}/${PW_VERSION}/${PW_TAR_FILE}"

ENV BUILD_DIR_BASE="/root"
ENV BUILD_DIR="${BUILD_DIR_BASE}/build-$PW_VERSION"

RUN curl -LJO $PW_TAR_URL \
    && tar -C $BUILD_DIR_BASE -xvf $PW_TAR_FILE

RUN cd $BUILD_DIR_BASE/pipewire-${PW_VERSION} \
    && meson setup $BUILD_DIR \
    && meson configure $BUILD_DIR -Dprefix=/usr \
    && meson compile -C $BUILD_DIR \
    && meson install -C $BUILD_DIR

# Clone and install pipewire-screenaudio
RUN git clone https://github.com/IceDBorn/pipewire-screenaudio.git \
    && cd pipewire-screenaudio \
    && bash install.sh

# Cleanup
RUN apt-get autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* \
    && rm -rf /home/kasm-default-profile/pipewire-1.0.4.tar \
    && chmod -R 755 /home/kasm-default-profile

COPY ./vnc_startup.sh $STARTUPDIR/vnc_startup.sh

# Userspace Runtime
ENV HOME /home/kasm-user

# Set environment variables
ENV XDG_DATA_DIRS=/app/data:/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:/home/kasm-user/.local/share/flatpak/exports/share

WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

# Set executable permission and allow launching for desktop files
RUN chmod +x /home/kasm-user/Desktop/*.desktop \
    && chmod +x /home/kasm-user/Desktop/*.desktop \
    && chmod 644 /home/kasm-user/Desktop/*.desktop \
    && chmod +x /home/kasm-default-profile/virtmic \
    && chmod +x /home/kasm-user/virtmic

# Download pipewire-screenaudio Firefox add-on XPI file
RUN wget -O /home/kasm-user/Downloads/pipewire-screenaudio.xpi "https://addons.mozilla.org/firefox/downloads/latest/pipewire-screenaudio/addon-1564124-latest.xpi"
RUN cp /home/kasm-user/Downloads/pipewire-screenaudio.xpi /home/kasm-default-profile/Downloads/pipewire-screenaudio.xpi
RUN mkdir -p /run/dbus && chown -R 1000:0 /run/dbus
RUN mkdir -p /dev/snd && chown -R 1000:0 /dev/snd
RUN $STARTUPDIR/set_user_permission.sh $HOME
USER 1000