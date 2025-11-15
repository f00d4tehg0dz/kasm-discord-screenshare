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

# Install Flatpak, xdg-desktop-portal for sandboxed applications
RUN apt-get update && apt-get install -y \
    flatpak \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    fuse3 \
    bubblewrap

# Setup Flatpak directories and permissions
RUN mkdir -p /home/kasm-user/.local/share/flatpak \
    && mkdir -p /var/lib/flatpak \
    && chmod 755 /home/kasm-user/.local/share/flatpak \
    && chmod 755 /var/lib/flatpak

# Install MPV and plex-mpv-shim for Plex playback control
RUN apt-get update && apt-get install -y \
    mpv \
    python3-pip \
    && pip3 install --no-cache-dir --break-system-packages \
    plex-mpv-shim \
    pystray \
    pillow \
    python-xlib

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

# Copy prebuilt Firefox extension
RUN mkdir -p /app/plex-firefox-ext
COPY ./plex-firefox-ext/plex-discord-control@local.xpi /app/plex-firefox-ext/

# Userspace Runtime
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
RUN $STARTUPDIR/set_user_permission.sh $HOME

# Create Firefox policies directory and add configuration for screen sharing
RUN mkdir -p /usr/lib/firefox/distribution \
    && echo '{\n  "policies": {\n    "Permissions": {\n      "Camera": {\n        "Allow": ["https://*", "http://*"]\n      },\n      "Microphone": {\n        "Allow": ["https://*", "http://*"]\n      }\n    },\n    "Preferences": {\n      "media.navigator.mediadatadecoder_vpx_enabled": true,\n      "media.peerconnection.enabled": true,\n      "media.getusermedia.screensharing.enabled": true,\n      "media.getusermedia.browser.enabled": true,\n      "media.getusermedia.audiocapture.enabled": true,\n      "media.navigator.permission.disabled": true\n    }\n  }\n}' > /usr/lib/firefox/distribution/policies.json

# Create Firefox user preferences for pipewire support
RUN mkdir -p /home/kasm-user/.mozilla/firefox \
    && mkdir -p /home/kasm-default-profile/.mozilla/firefox \
    && echo 'user_pref("media.cubeb.backend", "pipewire");\nuser_pref("media.cubeb.sandbox", false);\nuser_pref("media.getusermedia.screensharing.enabled", true);\nuser_pref("media.getusermedia.browser.enabled", true);\nuser_pref("media.getusermedia.audiocapture.enabled", true);\nuser_pref("media.navigator.permission.disabled", true);\nuser_pref("media.autoplay.default", 0);' > /home/kasm-user/.mozilla/firefox/user.js \
    && cp /home/kasm-user/.mozilla/firefox/user.js /home/kasm-default-profile/.mozilla/firefox/user.js

# Install WebSocket libraries for plex-discord-server and WSS proxy
RUN pip3 install --no-cache-dir --break-system-packages websockets aiohttp aiofiles

# Create plex-discord-server WebSocket server with inter-instance message forwarding
RUN mkdir -p /home/kasm-user/.local/bin && cat > /home/kasm-user/.local/bin/plex-discord-server << 'PYEOF'
#!/usr/bin/env python3
import asyncio, websockets, json, logging, ssl, argparse, sys, os
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)
IPC_SOCKET_PATH = os.environ.get('IPC_SOCKET_PATH', '/tmp/plex-discord-ipc.sock')
class PlexDiscordServer:
    def __init__(self, host='0.0.0.0', port=10100, ssl_context=None):
        self.host, self.port, self.clients, self.ssl_context = host, port, set(), ssl_context
        self.port_type = 'discord' if port == 10100 else 'browser'
        self.ipc_reader = None
        self.ipc_writer = None
        self.discord_bot = None  # Store Discord bot connection for responses
        self.pending_requests = {}  # Map request id to response handler
    async def connect_ipc(self):
        try:
            reader, writer = await asyncio.open_unix_connection(IPC_SOCKET_PATH)
            self.ipc_reader, self.ipc_writer = reader, writer
            logger.info(f'Connected to IPC socket for {self.port_type} instance')
            asyncio.create_task(self.read_ipc_messages())
        except Exception as e:
            logger.warning(f'Could not connect to IPC socket: {e}')
    async def read_ipc_messages(self):
        while True:
            try:
                line = await self.ipc_reader.readuntil(b'\n')
                if not line: break
                msg = json.loads(line.decode())
                # If this is a response (has id and status), route back to Discord bot
                if msg.get('id') and msg.get('status') and self.discord_bot:
                    logger.debug(f'Routing response back to Discord bot: {msg}')
                    try: await self.discord_bot.send(json.dumps(msg))
                    except: pass
                else:
                    await self.broadcast_to_clients(msg)
            except Exception as e:
                logger.debug(f'IPC read error: {e}')
                break
    async def send_to_ipc(self, message):
        if self.ipc_writer:
            try:
                self.ipc_writer.write((json.dumps(message) + '\n').encode())
                await self.ipc_writer.drain()
            except Exception as e:
                logger.debug(f'IPC send error: {e}')
    async def broadcast_to_clients(self, cmd):
        if not self.clients: return
        disconnected = set()
        for client in self.clients:
            try:
                await client.send(json.dumps(cmd))
                logger.debug(f'Sent command via IPC to browser client')
            except websockets.exceptions.ConnectionClosed:
                disconnected.add(client)
        if disconnected:
            self.clients -= disconnected
    async def handle_client(self, websocket, path):
        client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        try:
            if path == '/discord': logger.info(f'Discord bot connected from {client_id}'); await self.handle_discord_bot(websocket)
            elif path == '/browser': logger.info(f'Browser client connected from {client_id}'); await self.handle_browser_client(websocket)
            else: await websocket.send(json.dumps({'error': 'Unknown endpoint. Use /discord or /browser'}))
        except websockets.exceptions.ConnectionClosed: logger.info(f'Client disconnected: {client_id}')
        except Exception as e: logger.error(f'Error handling client: {e}')
    async def handle_discord_bot(self, websocket):
        self.discord_bot = websocket  # Store connection for response routing
        try:
            async for message in websocket:
                try:
                    cmd = json.loads(message)
                    logger.info(f'Discord command: {cmd.get("action")}')
                    await self.send_to_ipc(cmd)
                    if self.clients:
                        disconnected = set()
                        for client in self.clients:
                            try: await client.send(json.dumps(cmd))
                            except websockets.exceptions.ConnectionClosed: disconnected.add(client)
                        self.clients -= disconnected
                        await websocket.send(json.dumps({'status': 'command_sent', 'clients': len(self.clients)}))
                    else: await websocket.send(json.dumps({'status': 'command_sent', 'message': 'Command queued to IPC', 'clients': 0}))
                except json.JSONDecodeError: await websocket.send(json.dumps({'error': 'Invalid JSON'}))
        except websockets.exceptions.ConnectionClosed:
            logger.info('Discord bot disconnected')
            self.discord_bot = None
    async def handle_browser_client(self, websocket):
        self.clients.add(websocket); logger.info(f'Browser clients connected: {len(self.clients)}')
        try:
            await websocket.send(json.dumps({'type': 'ready', 'message': 'Extension connected to control server'}))
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data.get('type') == 'heartbeat': logger.debug(f'Heartbeat from browser client')
                    elif data.get('type') == 'status': logger.debug(f'Status from browser: {data}')
                    elif data.get('id'): logger.debug(f'Browser response: {data}'); await self.send_to_ipc(data)
                except json.JSONDecodeError: pass
        except websockets.exceptions.ConnectionClosed: logger.info('Browser client disconnected')
        finally: self.clients.discard(websocket); logger.info(f'Browser clients remaining: {len(self.clients)}')
ipc_clients = []
async def ipc_server(ready_event):
    if os.path.exists(IPC_SOCKET_PATH): os.remove(IPC_SOCKET_PATH)
    async def handle_ipc(reader, writer):
        ipc_clients.append({'reader': reader, 'writer': writer})
        logger.debug(f'IPC client connected, total: {len(ipc_clients)}')
        try:
            while True:
                line = await reader.readuntil(b'\n')
                if not line: break
                for client in ipc_clients:
                    if client['writer'] != writer:
                        try:
                            client['writer'].write(line)
                            await client['writer'].drain()
                        except:
                            pass
        except asyncio.IncompleteReadError:
            pass
        except Exception as e:
            logger.debug(f'IPC error: {e}')
        finally:
            ipc_clients.remove({'reader': reader, 'writer': writer})
    server = await asyncio.start_unix_server(handle_ipc, IPC_SOCKET_PATH)
    logger.info(f'IPC socket listening at {IPC_SOCKET_PATH}')
    ready_event.set()
    await server.serve_forever()
async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=10100, help='Port to bind to')
    parser.add_argument('--cert', help='Path to SSL certificate file')
    parser.add_argument('--key', help='Path to SSL key file')
    args = parser.parse_args()
    ssl_context = None
    protocol_scheme = 'ws'
    if args.cert and args.key:
        try:
            ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ssl_context.load_cert_chain(certfile=args.cert, keyfile=args.key)
            protocol_scheme = 'wss'
            logger.info(f'SSL enabled with cert: {args.cert}')
        except Exception as e:
            logger.error(f'Failed to load SSL certificates: {e}')
            sys.exit(1)
    server = PlexDiscordServer(host=args.host, port=args.port, ssl_context=ssl_context)
    if args.port == 10100:
        ready_event = asyncio.Event()
        asyncio.create_task(ipc_server(ready_event))
        await ready_event.wait()
    await server.connect_ipc()
    logger.info('='*60); logger.info('Plex Discord Control Server'); logger.info('='*60)
    logger.info(f'Starting WebSocket server on {protocol_scheme}://{args.host}:{args.port}')
    logger.info(f'Discord bots connect to: {protocol_scheme}://localhost:{args.port}/discord')
    logger.info(f'Browser extensions connect to: {protocol_scheme}://localhost:{args.port}/browser')
    logger.info('='*60)
    async with websockets.serve(server.handle_client, server.host, server.port, ssl=ssl_context):
        logger.info('Server running... Press Ctrl+C to stop')
        try: await asyncio.Future()
        except KeyboardInterrupt: logger.info('Shutting down...')
if __name__ == '__main__': asyncio.run(main())
PYEOF

RUN chmod +x /home/kasm-user/.local/bin/plex-discord-server

# Create WebSocket SSL/WSS proxy for Firefox extension compatibility
RUN cat > /home/kasm-user/.local/bin/websocket-proxy << 'PROXYEOF'
#!/usr/bin/env python3
import asyncio
import ssl
import websockets
import json
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

async def proxy_websocket(websocket, path):
    """Proxy WebSocket connections from WSS (client) to WSS (backend)"""
    try:
        # Create SSL context for connecting to the backend server (self-signed certificate)
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # Route to correct backend endpoint based on incoming path
        backend_path = path if path in ['/discord', '/browser'] else '/browser'
        # Use 127.0.0.1 instead of localhost for direct connection to loopback interface
        backend_url = f'wss://127.0.0.1:10100{backend_path}'
        logger.info(f'Routing incoming path {path} to backend: {backend_url}')

        async with websockets.connect(backend_url, ssl=ssl_context) as backend:
            async def forward_from_client():
                try:
                    async for message in websocket:
                        await backend.send(message)
                except websockets.exceptions.ConnectionClosed:
                    pass

            async def forward_from_backend():
                try:
                    async for message in backend:
                        await websocket.send(message)
                except websockets.exceptions.ConnectionClosed:
                    pass

            await asyncio.gather(forward_from_client(), forward_from_backend())
    except Exception as e:
        logger.error(f"Proxy error: {e}")

async def main():
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(
        certfile='/home/kasm-user/.vnc/self.pem',
        keyfile='/home/kasm-user/.vnc/self.pem'
    )

    async with websockets.serve(proxy_websocket, '0.0.0.0', 10101, ssl=ssl_context):
        logger.info('='*60)
        logger.info('WebSocket SSL Proxy (WSS)')
        logger.info('='*60)
        logger.info('WSS Proxy listening on wss://0.0.0.0:10101')
        logger.info('Routing Discord and Browser connections to backend')
        logger.info('='*60)
        await asyncio.Future()  # run forever

if __name__ == '__main__':
    asyncio.run(main())
PROXYEOF

RUN chmod +x /home/kasm-user/.local/bin/websocket-proxy && \
    chown -R 1000:0 /home/kasm-user/.local/bin/websocket-proxy

EXPOSE 10009 10100 10101

USER 1000