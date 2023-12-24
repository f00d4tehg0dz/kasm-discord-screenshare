ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-jammy"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG
USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########

# Remove PulseAudio and Install PipeWire
RUN apt-get update -y \
    && apt-get remove -y pulseaudio \
    && rm /usr/share/alsa/alsa.conf.d/50-pulseaudio.conf \
    && apt-get install -y pipewire-media-session- \
    && apt-get install -y pipewire-audio-client-libraries \
    && apt-get install -y libspa-0.2-jack libspa-0.2-bluetooth pulseaudio-module-bluetooth- \
    && apt-get install debhelper-compat \
    findutils        \
    git              \
    libasound2-dev   \
    libdbus-1-dev    \
    libglib2.0-dev   \
    libsbc-dev       \
    libsdl2-dev      \
    libudev-dev      \
    libva-dev        \
    libv4l-dev       \
    libx11-dev       \
    ninja-build      \
    pkg-config       \
    python3-docutils \
    python3-pip      \
    meson            \
    pulseaudio       \
    dbus-x11         \
    rtkit -y         \
    fonts-liberation \
    libu2f-udev      \
    xdg-utils        \
    unzip            \
    && ldconfig      \
    && rm -rf /var/lib/apt/lists/*

# Install chrome latest
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN apt-get install -y ./google-chrome-stable_current_amd64.deb

# Install chromedriver 114
RUN wget https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip
RUN mv chromedriver /bin

# Create desktop shortcut for Chromium
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Chromium Web Browser\nComment=Browse the World Wide Web\nGenericName=Web Browser\nExec=/usr/bin/google-chrome-stable --no-sandbox %U\nIcon=chromium\nType=Application\nCategories=Network;WebBrowser;\n' > $HOME/Desktop/chromium.desktop \
    && chmod +x $HOME/Desktop/chromium.desktop

# Download and setup virtmic
RUN curl -L "https://github.com/edisionnano/Screenshare-with-audio-on-Discord-with-Linux/blob/main/virtmic?raw=true" -o virtmic \
    && chmod +x virtmic

# Install dependencies for discord-screenaudio
RUN apt-get update \
    && apt-get install -y build-essential cmake qtbase5-dev qtwebengine5-dev libkf5notifications-dev libkf5xmlgui-dev libkf5globalaccel-dev pkg-config libpipewire-0.3 git \
    && rm -rf /var/lib/apt/lists/*

# Clone and build discord-screenaudio
RUN git clone https://github.com/maltejur/discord-screenaudio.git \
    && cd discord-screenaudio \
    && cmake -B build \
    && cmake --build build --config Release \
    && cmake --install build

# Create desktop shortcut for discord-screenaudio
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Discord ScreenAudio\nComment=Custom Discord client with screen audio streaming\nExec=/usr/local/bin/discord-screenaudio\nIcon=discord\nType=Application\nCategories=Network;Communication;\n' > $HOME/Desktop/discord-audio.desktop \
    && chmod +x $HOME/Desktop/discord-audio.desktop

ARG PW_VERSION=1.0.0
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

# Cleanup
RUN apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* \
    && chmod -R 755 /home/kasm-default-profile

######### End Customizations ###########

COPY ./vnc_startup.sh $STARTUPDIR/vnc_startup.sh

# Userspace Runtime
ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME
RUN mkdir -p /run/dbus && chown -R 1000:0 /run/dbus
RUN mkdir -p /dev/snd && chown -R 1000:0 /dev/snd
RUN $STARTUPDIR/set_user_permission.sh $HOME
USER 1000
#CMD ["--tail-log"]