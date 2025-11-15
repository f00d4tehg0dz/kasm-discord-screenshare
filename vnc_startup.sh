#!/bin/bash
### every exit != 0 fails the script
set -e

no_proxy="localhost,127.0.0.1"

if [ -f /usr/bin/kasm-profile-sync ]; then
	kasm_profile_sync_found=1
fi

# Set lang values
if [ "${LC_ALL}" != "en_US.UTF-8" ]; then
  export LANG=${LC_ALL}
  export LANGUAGE=${LC_ALL}
fi

# dict to store processes
declare -A KASM_PROCS

# switch passwords to local variables
tmpval=$VNC_VIEW_ONLY_PW
unset VNC_VIEW_ONLY_PW
VNC_VIEW_ONLY_PW=$tmpval
tmpval=$VNC_PW
unset VNC_PW
VNC_PW=$tmpval

BUILD_ARCH=$(uname -p)
if [ -z ${KASM_PROFILE_CHUNK_SIZE} ]; then
  KASM_PROFILE_CHUNK_SIZE=100000
fi
if [ -z ${DRINODE+x} ]; then
  DRINODE="/dev/dri/renderD128"
fi
KASMNVC_HW3D=''
if [ ! -z ${HW3D+x} ]; then
  KASMVNC_HW3D="-hw3d"
fi

# startup 01_envs.sh
export DISABLE_RTKIT=y
export XDG_RUNTIME_DIR=/tmp
export PIPEWIRE_RUNTIME_DIR=/tmp
export PULSE_RUNTIME_DIR=/tmp

# startup/10_dbus.sh
# Clean up stale dbus files and ensure proper directory structure
rm -rf /run/dbus 2>/dev/null || true
mkdir -p /run/dbus 2>/dev/null || true

# Start session bus for user (required for Flatpak and PipeWire)
# Don't start system dbus as it causes permission issues in Docker
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
mkdir -p /run/user/1000
chmod 700 /run/user/1000
if ! [ -S /run/user/1000/bus ]; then
    echo "Starting DBus session bus..."
    dbus-daemon --session --address="unix:path=/run/user/1000/bus" --print-address --fork 2>/dev/null || echo "DBus session initialization: $(dbus-daemon --session --address="unix:path=/run/user/1000/bus" --print-address --fork 2>&1)"
fi

# startup/20_flatpak.sh
# Initialize Flatpak environment for sandboxed applications (Plex Desktop, etc.)
echo "Initializing Flatpak environment..."

# Ensure Flatpak directories exist with proper permissions (user-writable directories only)
mkdir -p /home/kasm-user/.local/share/flatpak 2>/dev/null || true
mkdir -p /tmp/.flatpak-cache 2>/dev/null || true
chmod 1777 /tmp/.flatpak-cache 2>/dev/null || true

# Set Flatpak environment variables
export XDG_DATA_DIRS="/home/kasm-user/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/app/data:/usr/local/share:/usr/share"

# Optional: Try to start user systemd session for enhanced Flatpak support (non-critical)
if command -v systemd-run &>/dev/null 2>&1; then
    systemd-run --user --scope --property=KillMode=process true 2>/dev/null || echo "systemd user session not available (expected in Docker)"
fi

# Start XDG Desktop Portal for Flatpak sandboxing support
echo "Starting XDG Desktop Portal for Flatpak..."
if ! pgrep -f xdg-desktop-portal > /dev/null 2>&1; then
    /usr/libexec/xdg-desktop-portal &
    sleep 1
    echo "XDG Desktop Portal started"
else
    echo "XDG Desktop Portal already running"
fi

# startup/21_plex_mpv_shim.sh
# Configure plex-mpv-shim for Plex playback control
echo "Configuring plex-mpv-shim..."

# Create config directory for plex-mpv-shim
mkdir -p /home/kasm-user/.config/plex-mpv-shim 2>/dev/null || true
mkdir -p /home/kasm-default-profile/.config/plex-mpv-shim 2>/dev/null || true
chmod 755 /home/kasm-user/.config/plex-mpv-shim 2>/dev/null || true
chown -R 1000:0 /home/kasm-user/.config/plex-mpv-shim 2>/dev/null || true

echo "plex-mpv-shim configured and ready to use"

STARTUP_COMPLETE=0

######## FUNCTION DECLARATIONS ##########

## print out help
function help (){
	echo "
		USAGE:

		OPTIONS:
		-w, --wait      (default) keeps the UI and the vncserver up until SIGINT or SIGTERM will received
		-s, --skip      skip the vnc startup and just execute the assigned command.
		                example: docker run kasmweb/core --skip bash
		-d, --debug     enables more detailed startup output
		                e.g. 'docker run kasmweb/core --debug bash'
		-h, --help      print out this help
		"
}

trap cleanup SIGINT SIGTERM SIGQUIT SIGHUP ERR

function pull_profile (){
	if [ ! -z "$KASM_PROFILE_LDR" ]; then
		if [ -z "$kasm_profile_sync_found" ]; then
			echo >&2 "Profile sync not available"
			sleep 3
			http_proxy="" https_proxy="" curl -k "https://${KASM_API_HOST}:${KASM_API_PORT}/api/set_kasm_session_status?token=${KASM_API_JWT}" -H 'Content-Type: application/json' -d '{"status": "running"}'
			return
		fi

		echo "Downloading and unpacking user profile from object storage."
		set +e
		if [[ $DEBUG == true ]]; then
			http_proxy="" https_proxy="" /usr/bin/kasm-profile-sync --download /home/kasm-user --insecure --remote ${KASM_API_HOST} --port ${KASM_API_PORT} -c ${KASM_PROFILE_CHUNK_SIZE} --token ${KASM_API_JWT} --verbose
		else
			http_proxy="" https_proxy="" /usr/bin/kasm-profile-sync --download /home/kasm-user --insecure --remote ${KASM_API_HOST} --port ${KASM_API_PORT} -c ${KASM_PROFILE_CHUNK_SIZE} --token ${KASM_API_JWT}
		fi
		PROCESS_SYNC_EXIT_CODE=$?
		set -e
		if (( PROCESS_SYNC_EXIT_CODE > 1 )); then
			echo "Profile-sync failed with a non-recoverable error. See server side logs for more details."
			exit 1
		fi
		echo "Profile load complete."
		# Update the status of the container to running
		sleep 3
		http_proxy="" https_proxy="" curl -k "https://${KASM_API_HOST}:${KASM_API_PORT}/api/set_kasm_session_status?token=${KASM_API_JWT}" -H 'Content-Type: application/json' -d '{"status": "running"}'

	fi
}

function profile_size_check(){
	if [ ! -z "$KASM_PROFILE_SIZE_LIMIT" ]
	then
		SIZE_CHECK_FAILED=false
		while true
		do
			sleep 60
			CURRENT_SIZE=$(du -s $HOME | grep -Po '^\d+')
			SIZE_LIMIT_MB=$(echo "$KASM_PROFILE_SIZE_LIMIT / 1000" | bc)
			if [[ $CURRENT_SIZE -gt KASM_PROFILE_SIZE_LIMIT ]]
			then
				notify-send "Profile Size Exceeds Limit" "Your home profile has exceeded the size limit of ${SIZE_LIMIT_MB}MB. Changes on your desktop will not be saved between sessions until you reduce the size of your profile." -i /usr/share/icons/ubuntu-mono-dark/apps/22/dropboxstatus-x.svg -t 57000
				SIZE_CHECK_FAILED=true
			else
				if [ "$SIZE_CHECK_FAILED" = true ] ; then
					SIZE_CHECK_FAILED=false
					notify-send "Profile Size" "Your home profile size is now under the limit and will be saved when your session is terminated." -i /usr/share/icons/ubuntu-mono-dark/apps/22/dropboxstatus-logo.svg -t 57000
				fi
			fi
		done
	fi
}

## correct forwarding of shutdown signal
function cleanup () {
    kill -s SIGTERM $!
    exit 0
}

function start_kasmvnc (){
	if [[ $DEBUG == true ]]; then
	  echo -e "\n------------------ Start KasmVNC Server ------------------------"
	fi

	DISPLAY_NUM=$(echo $DISPLAY | grep -Po ':\d+')

	if [[ $STARTUP_COMPLETE == 0 ]]; then
	    vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
	    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
	    || echo "no locks present"
	fi

	rm -rf $HOME/.vnc/*.pid

	# Clean XFCE config to prevent "Unable to contact settings server" error
	# This must happen before XFCE starts for the first time
	rm -rf $HOME/.config/xfce4 2>/dev/null || true
	rm -rf $HOME/.cache/xfce4 2>/dev/null || true

	# Create xstartup script that properly initializes the desktop
	cat > $HOME/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash
# XVnc startup script

# Set DISPLAY for this script
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Log startup for debugging
echo "[$(date)] xstartup started, user: $USER, PID: $$" > /tmpplexcontrol/xstartup-debug.log

# Start XFCE4 desktop environment
if [ -x /usr/bin/xfce4-session ]; then
    echo "[$(date)] Starting xfce4-session..." >> /tmp/xstartup-debug.log
    # Start xfce4-session directly in the background
    # Set DISPLAY explicitly to avoid issues
    export DISPLAY=:1
    /usr/bin/xfce4-session >> /tmp/xstartup-debug.log 2>&1 &
    XFCE_PID=$!
    echo "[$(date)] xfce4-session started with PID: $XFCE_PID" >> /tmp/xstartup-debug.log
else
    echo "[$(date)] xfce4-session not found, falling back to xterm" >> /tmp/xstartup-debug.log
    # Fallback to xterm if XFCE not available
    xterm >> /tmp/xstartup-debug.log 2>&1 &
fi

# SSL certificate is now generated in main vnc_startup.sh before vncserver starts
# No need to regenerate it here - it's already at $HOME/.vnc/self.pem with CN=localhost, discord.xxx.com and SANs
echo "[$(date)] Using pre-generated SSL certificate at $HOME/.vnc/self.pem" >> /tmp/xstartup-debug.log

if command -v plex-discord-server &> /dev/null; then
    echo "[$(date)] Starting plex-discord-server instances..." >> /tmp/xstartup-debug.log
    # Instance 1: Listen on 0.0.0.0:10100 with SSL for external WSS connections
    # This instance creates the IPC server socket that port 10009 will connect to
    plex-discord-server --host 0.0.0.0 --port 10100 --cert "$HOME/.vnc/self.pem" --key "$HOME/.vnc/self.pem" > /tmp/websocket-wss.log 2>&1 &
    WS_PID_WSS=$!
    echo "[$(date)] plex-discord-server WSS started with PID: $WS_PID_WSS (wss://0.0.0.0:10100)" >> /tmp/xstartup-debug.log

    # Wait for IPC socket to be created before starting the WS instance
    sleep 3
    echo "[$(date)] Waited 3 seconds for IPC socket initialization..." >> /tmp/xstartup-debug.log

    # Instance 2: Listen on 127.0.0.1:10009 without SSL for local Firefox extension (plain WS)
    # This instance connects to the IPC socket created by port 10100 instance
    plex-discord-server --host 127.0.0.1 --port 10009 > /tmp/websocket-ws.log 2>&1 &
    WS_PID_WS=$!
    echo "[$(date)] plex-discord-server WS started with PID: $WS_PID_WS (ws://127.0.0.1:10009)" >> /tmp/xstartup-debug.log

    WS_PID=$WS_PID_WSS
elif [ -x /home/kasm-user/.local/bin/plex-discord-server ]; then
    echo "[$(date)] Starting plex-discord-server instances from local path..." >> /tmp/xstartup-debug.log
    # Instance 1: Listen on 0.0.0.0:10100 with SSL for external WSS connections
    # This instance creates the IPC server socket that port 10009 will connect to
    python3 /home/kasm-user/.local/bin/plex-discord-server --host 0.0.0.0 --port 10100 --cert "$HOME/.vnc/self.pem" --key "$HOME/.vnc/self.pem" > /tmp/websocket-wss.log 2>&1 &
    WS_PID_WSS=$!
    echo "[$(date)] plex-discord-server WSS started with PID: $WS_PID_WSS (wss://0.0.0.0:10100)" >> /tmp/xstartup-debug.log

    # Wait for IPC socket to be created before starting the WS instance
    sleep 3
    echo "[$(date)] Waited 3 seconds for IPC socket initialization..." >> /tmp/xstartup-debug.log

    # Instance 2: Listen on 127.0.0.1:10009 without SSL for local Firefox extension (plain WS)
    # This instance connects to the IPC socket created by port 10100 instance
    python3 /home/kasm-user/.local/bin/plex-discord-server --host 127.0.0.1 --port 10009 > /tmp/websocket-ws.log 2>&1 &
    WS_PID_WS=$!
    echo "[$(date)] plex-discord-server WS started with PID: $WS_PID_WS (ws://127.0.0.1:10009)" >> /tmp/xstartup-debug.log

    WS_PID=$WS_PID_WSS
else
    echo "[$(date)] ERROR: plex-discord-server not found in PATH or /home/kasm-user/.local/bin" >> /tmp/xstartup-debug.log
fi

# Verify plex-discord-server started successfully
sleep 2
if [ ! -z "$WS_PID" ] && kill -0 $WS_PID 2>/dev/null; then
    echo "[$(date)] plex-discord-server is running successfully on port 10100 (WSS)" >> /tmp/xstartup-debug.log
else
    echo "[$(date)] ERROR: plex-discord-server failed to start. Check /tmp/websocket.log" >> /tmp/xstartup-debug.log
fi

# Start WebSocket SSL proxy on port 10101 (for external Discord bot connections via nginx)
echo "[$(date)] Starting WebSocket SSL proxy on port 10101..." >> /tmp/xstartup-debug.log
if [ -x /home/kasm-user/.local/bin/websocket-proxy ]; then
    python3 /home/kasm-user/.local/bin/websocket-proxy > /tmp/websocket-proxy.log 2>&1 &
    PROXY_PID=$!
    echo "[$(date)] WebSocket SSL proxy started with PID: $PROXY_PID (wss://0.0.0.0:10101)" >> /tmp/xstartup-debug.log

    # Verify proxy started
    sleep 2
    if kill -0 $PROXY_PID 2>/dev/null; then
        echo "[$(date)] WebSocket SSL proxy is running successfully on port 10101" >> /tmp/xstartup-debug.log
    else
        echo "[$(date)] ERROR: WebSocket SSL proxy failed to start. Check /tmp/websocket-proxy.log" >> /tmp/xstartup-debug.log
    fi
else
    echo "[$(date)] WARNING: websocket-proxy not found at /home/kasm-user/.local/bin/websocket-proxy" >> /tmp/xstartup-debug.log
fi

# Keep the script running for other services
sleep infinity
XSTARTUP
	chmod +x $HOME/.vnc/xstartup

	# Install prebuilt Firefox Extension (.xpi file)
	echo "Installing Plex Discord Control Firefox Extension..."

	# Firefox extensions must be unpacked into a folder structure, not left as .xpi files
	FIREFOX_PROFILE="$HOME/.mozilla/firefox/kasm"
	EXT_FOLDER="$FIREFOX_PROFILE/extensions/plex-discord-control@local"
	EXT_XPI_PATH="/app/plex-firefox-ext/plex-discord-control@local.xpi"

	if [ -f "$EXT_XPI_PATH" ]; then
		echo "Found Firefox extension XPI at: $EXT_XPI_PATH"

		# Create extension directory
		mkdir -p "$EXT_FOLDER"

		# Remove old extension files to avoid permission issues on re-extraction
		rm -rf "$EXT_FOLDER"/* 2>/dev/null || true

		# Unpack the .xpi file (it's just a ZIP archive) into the extension folder
		unzip -q "$EXT_XPI_PATH" -d "$EXT_FOLDER"

		# List unpacked files
		echo "Unpacked files in $EXT_FOLDER:"
		ls -la "$EXT_FOLDER" 2>/dev/null || echo "Failed to list unpacked files"

		if [ -f "$EXT_FOLDER/manifest.json" ]; then
			echo "✓ Firefox Extension unpacked: $EXT_FOLDER"

			# Create/update extensions.json metadata file to register the extension
			# Firefox requires extensions to be explicitly registered in extensions.json
			EXT_JSON="$FIREFOX_PROFILE/extensions.json"

			# Create extensions.json with proper extension metadata
			# Firefox requires absolute paths for unpacked extensions
			cat > "$EXT_JSON" << EXTJSON
{
  "schemaVersion": 4,
  "addons": [
    {
      "id": "plex-discord-control@local",
      "version": "1.2.1",
      "location": "app-system",
      "path": "$EXT_FOLDER",
      "type": "extension",
      "enabled": true,
      "applicationVersion": "89.0",
      "platformVersion": "89.0"
    }
  ]
}
EXTJSON

			echo "✓ Firefox Extension registered in extensions.json"
		else
			echo "⚠ Error: Failed to unpack .xpi file or manifest.json not found"
		fi
	else
		echo "⚠ Warning: Prebuilt .xpi file not found at $EXT_XPI_PATH"
		echo "  Extension will not be available"
	fi

	# Configure Firefox for WebSocket connections and certificate handling
	# Create user.js which Firefox reads BEFORE applying default preferences
	FIREFOX_USERJS="$FIREFOX_PROFILE/user.js"

	# Create user.js with settings for WebSocket connections and self-signed cert handling
	cat > "$FIREFOX_USERJS" << 'USERJS'
// Allow connections without strict HTTPS requirements
user_pref("dom.security.https_only_mode", false);
user_pref("security.mixed_content.block_active_content", false);
// Disable OCSP (Online Certificate Status Protocol) checking which can cause issues with self-signed certs
user_pref("security.OCSP.enabled", 0);
user_pref("security.cert_pinning.enforcement_level", 0);
// Allow insecure connections to localhost (needed for self-signed certs in development)
user_pref("security.fileuri.strict_origin_policy", false);
USERJS

	echo "✓ Firefox user.js configured for WebSocket and self-signed certificate support"

	# Create profiles.ini to define the Firefox profile
	mkdir -p "$HOME/.mozilla/firefox"
	cat > "$HOME/.mozilla/firefox/profiles.ini" << 'PROFILES'
[Profile0]
Name=kasm
IsRelative=1
Path=kasm
Default=1
PROFILES

	# Also install to kasm-default-profile if it exists
	if [ -d /home/kasm-default-profile ] && [ -f "$EXT_XPI_PATH" ]; then
		EXT_DEFAULT_PATH="/home/kasm-default-profile/.mozilla/firefox/kasm/extensions/plex-discord-control@local.xpi"
		mkdir -p "$(dirname "$EXT_DEFAULT_PATH")"
		cp "$EXT_XPI_PATH" "$EXT_DEFAULT_PATH" 2>/dev/null || true
	fi

	VNCOPTIONS="$VNCOPTIONS -select-de manual"

	# Disabled -UnixRelay printer option due to VNC server compatibility issues
	# if [[ ${KASM_SVC_PRINTER:-1} == 1 ]]; then
	#	VNCOPTIONS="$VNCOPTIONS -UnixRelay printer:/tmp/printer"
	# fi

	if [[ "${BUILD_ARCH}" =~ ^aarch64$ ]] && [[ -f /lib/aarch64-linux-gnu/libgcc_s.so.1 ]] ; then
		LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1 vncserver $DISPLAY $KASMVNC_HW3D -drinode $DRINODE -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -websocketPort $NO_VNC_PORT -httpd ${KASM_VNC_PATH}/www -FrameRate=$MAX_FRAME_RATE -interface 0.0.0.0 -BlacklistThreshold=0 -FreeKeyMappings $VNCOPTIONS $KASM_SVC_SEND_CUT_TEXT $KASM_SVC_ACCEPT_CUT_TEXT
	else
		vncserver $DISPLAY $KASMVNC_HW3D -drinode $DRINODE -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -websocketPort $NO_VNC_PORT -httpd ${KASM_VNC_PATH}/www -FrameRate=$MAX_FRAME_RATE -interface 0.0.0.0 -BlacklistThreshold=0 -FreeKeyMappings $VNCOPTIONS $KASM_SVC_SEND_CUT_TEXT $KASM_SVC_ACCEPT_CUT_TEXT
	fi

	KASM_PROCS['kasmvnc']=$(cat $HOME/.vnc/*${DISPLAY_NUM}.pid)

	#Disable X11 Screensaver
	if [ "${DISTRO}" != "alpine" ]; then
		echo "Disabling X Screensaver Functionality"
		xset -dpms
		xset s off
		xset q
	else
		echo "Disabling of X Screensaver Functionality for $DISTRO is not required."
	fi

	if [[ $DEBUG == true ]]; then
	  echo -e "\n------------------ Started Websockify  ----------------------------"
	  echo "Websockify PID: ${KASM_PROCS['kasmvnc']}";
	fi
}

function start_window_manager (){
	echo -e "\n------------------ Xfce4 window manager startup------------------"

	if [ "${START_XFCE4}" == "1" ] ; then
		echo "XFCE4 will be started by VNC xstartup script"
		# XFCE is now started by the xstartup script with proper initialization
		# and config cleanup happens earlier in the startup process
		sleep 2
	else
		echo "Skipping XFCE Startup"
	fi
}

function start_audio_out_websocket (){
	if [[ ${KASM_SVC_AUDIO:-1} == 1 ]]; then
		echo 'Starting audio websocket server'
		$STARTUPDIR/jsmpeg/kasm_audio_out-linux kasmaudio 8081 4901 ${HOME}/.vnc/self.pem ${HOME}/.vnc/self.pem "kasm_user:$VNC_PW"  &

		KASM_PROCS['kasm_audio_out_websocket']=$!

		if [[ $DEBUG == true ]]; then
		  echo -e "\n------------------ Started Audio Out Websocket  ----------------------------"
		  echo "Kasm Audio Out Websocket PID: ${KASM_PROCS['kasm_audio_out_websocket']}";
		fi
	fi
}

function start_audio_out (){
    if [[ ${KASM_SVC_AUDIO:-1} == 1 ]]; then
		echo 'Starting audio server'

        if [ "${START_PIPEWIRE:-0}" == "1" ] ;
        then
            # Fix PipeWire directory permissions and ownership
            mkdir -p /tmp/runtime-kasm-user/pulse
            [ -d /tmp/pipewire-0 ] && chmod 755 /tmp/pipewire-0 || true
            chmod 755 /tmp/runtime-kasm-user /tmp/runtime-kasm-user/pulse
            chown 1000:0 /tmp/runtime-kasm-user /tmp/runtime-kasm-user/pulse
            rm -f /tmp/pipewire-0.lock /tmp/pipewire-0/lock /tmp/runtime-kasm-user/pulse/native

            # Set environment variables for PipeWire
            export PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user
            export PULSE_RUNTIME_PATH=/tmp/runtime-kasm-user/pulse
            export PULSE_SERVER="unix:${PULSE_RUNTIME_PATH}/native"

            # Kill any existing PipeWire processes to avoid conflicts
            pkill -f pipewire || true
            pkill -f wireplumber || true
            sleep 1

            # Clean up old sockets
            rm -f /tmp/pipewire-0.lock /tmp/pipewire-0/lock /tmp/runtime-kasm-user/pulse/native 2>/dev/null || true

            echo "Starting PipeWire daemon..."
            PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user pipewire > /tmp/pipewire.log 2>&1 &
            sleep 3

            echo "Starting WirePlumber..."
            PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user wireplumber > /tmp/wireplumber.log 2>&1 &
            sleep 2

            echo "Starting PipeWire-Pulse..."
            PIPEWIRE_RUNTIME_DIR=/tmp/runtime-kasm-user PULSE_RUNTIME_PATH=/tmp/runtime-kasm-user/pulse pipewire-pulse > /tmp/pipewire-pulse.log 2>&1 &
            sleep 2

            # Wait for PulseAudio socket to be ready
            echo "Waiting for PulseAudio socket..."
            MAX_RETRIES=10
            RETRY=0
            while [ ! -S /tmp/runtime-kasm-user/pulse/native ] && [ $RETRY -lt $MAX_RETRIES ]; do
                echo "Waiting for pulse socket... ($RETRY/$MAX_RETRIES)"
                sleep 1
                RETRY=$((RETRY + 1))
            done

            if [ ! -S /tmp/runtime-kasm-user/pulse/native ]; then
                echo "WARNING: PulseAudio socket not ready, audio may not work"
            else
                echo "PulseAudio socket ready"
            fi
        fi

		if [[ $DEBUG == true ]]; then
			echo 'Starting audio service'
			# Check if ffmpeg audio streaming is already running
			if ! pgrep -f "ffmpeg.*kasmaudio" > /dev/null; then
				echo "Starting ffmpeg audio streaming (with retry)..."
				# Use timeout and retry mechanism for ffmpeg
				PIPEWIRE_LATENCY=2000/44100 PULSE_SERVER="unix:/tmp/runtime-kasm-user/pulse/native" no_proxy=127.0.0.1 ffmpeg -rtbufsize 100M -v verbose -f pulse -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio 2>/tmp/ffmpeg_audio.log &
				KASM_PROCS['kasm_audio_out']=$!
				echo -e "\n------------------ Started Audio Out  ----------------------------"
				echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				# Give it a moment to start and check if it's still running
				sleep 1
				if kill -0 "${KASM_PROCS['kasm_audio_out']}" 2>/dev/null; then
					echo "Audio streaming process is running successfully"
				else
					echo "WARNING: Audio streaming process died immediately after start"
				fi
			else
				echo "Audio streaming already running"
				# Get the PID of the existing ffmpeg process
				EXISTING_PID=$(pgrep -f "ffmpeg.*kasmaudio" | head -1)
				if [[ -n "$EXISTING_PID" ]]; then
					KASM_PROCS['kasm_audio_out']=$EXISTING_PID
					echo -e "\n------------------ Audio Out Already Running  ----------------------------"
					echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				else
					echo "Warning: Could not find existing ffmpeg PID, starting new process"
					PIPEWIRE_LATENCY=2000/44100 no_proxy=127.0.0.1 ffmpeg -v verbose -f pulse -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio &
					KASM_PROCS['kasm_audio_out']=$!
					echo -e "\n------------------ Started Audio Out  ----------------------------"
					echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				fi
			fi
		else
			echo 'Starting audio service'
			# Check if ffmpeg audio streaming is already running
			if ! pgrep -f "ffmpeg.*kasmaudio" > /dev/null; then
				echo "Starting ffmpeg audio streaming (with retry)..."
				# Use explicit PULSE_SERVER and timeout for ffmpeg
				PIPEWIRE_LATENCY=2000/44100 PULSE_SERVER="unix:/tmp/runtime-kasm-user/pulse/native" no_proxy=127.0.0.1 ffmpeg -rtbufsize 100M -v verbose -f pulse -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio 2>/tmp/ffmpeg_audio.log &
				KASM_PROCS['kasm_audio_out']=$!
				echo -e "\n------------------ Started Audio Out  ----------------------------"
				echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				# Give it a moment to start and check if it's still running
				sleep 1
				if kill -0 "${KASM_PROCS['kasm_audio_out']}" 2>/dev/null; then
					echo "Audio streaming process is running successfully"
				else
					echo "WARNING: Audio streaming process died immediately after start"
				fi
			else
				echo "Audio streaming already running"
				# Get the PID of the existing ffmpeg process
				EXISTING_PID=$(pgrep -f "ffmpeg.*kasmaudio" | head -1)
				if [[ -n "$EXISTING_PID" ]]; then
					KASM_PROCS['kasm_audio_out']=$EXISTING_PID
					echo -e "\n------------------ Audio Out Already Running  ----------------------------"
					echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				else
					echo "Warning: Could not find existing ffmpeg PID, starting new process"
					PIPEWIRE_LATENCY=2000/44100 no_proxy=127.0.0.1 ffmpeg -v verbose -f pulse -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio &
					KASM_PROCS['kasm_audio_out']=$!
					echo -e "\n------------------ Started Audio Out  ----------------------------"
					echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
				fi
			fi
		fi
	fi
}

function start_audio_in (){
	if [[ ${KASM_SVC_AUDIO_INPUT:-1} == 1 ]]; then
		echo 'Starting audio input server'
		$STARTUPDIR/audio_input/kasm_audio_input_server --ssl --auth-token "kasm_user:$VNC_PW" --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &

		KASM_PROCS['kasm_audio_in']=$!

		if [[ $DEBUG == true ]]; then
			echo -e "\n------------------ Started Audio Out Websocket  ----------------------------"
			echo "Kasm Audio In PID: ${KASM_PROCS['kasm_audio_in']}";
		fi
	fi
}

function start_upload (){
	if [[ ${KASM_SVC_UPLOADS:-1} == 1 ]]; then
		echo 'Starting upload server'
		$STARTUPDIR/upload_server/kasm_upload_server --ssl --auth-token "kasm_user:$VNC_PW" &

		KASM_PROCS['upload_server']=$!

		if [[ $DEBUG == true ]]; then
			echo -e "\n------------------ Started Upload Server  ----------------------------"
			echo "Upload Server PID: ${KASM_PROCS['upload_server']}";
		fi
	fi
}

function start_gamepad (){
	if [[ ${KASM_SVC_GAMEPAD:-1} == 1 ]]; then
		echo 'Starting gamepad server'
		$STARTUPDIR/gamepad/kasm_gamepad_server --ssl --auth-token "kasm_user:$VNC_PW" --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &

		KASM_PROCS['kasm_gamepad']=$!

		if [[ $DEBUG == true ]]; then
			echo -e "\n------------------ Started Gamepad Websocket  ----------------------------"
			echo "Kasm Gamepad PID: ${KASM_PROCS['kasm_gamepad']}";
		fi
	fi
}

function start_webcam (){
	if [[ ${KASM_SVC_WEBCAM:-1} == 1 ]] && [[ -e /dev/video0 ]]; then
		echo 'Starting webcam server'
                if [[ $DEBUG == true ]]; then
			$STARTUPDIR/webcam/kasm_webcam_server --debug --port 4905 --ssl --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &
		else
			$STARTUPDIR/webcam/kasm_webcam_server --port 4905 --ssl --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &
		fi

		KASM_PROCS['kasm_webcam']=$!

		if [[ $DEBUG == true ]]; then
			echo -e "\n------------------ Started Webcam Websocket  ----------------------------"
			echo "Kasm Webcam PID: ${KASM_PROCS['kasm_webcam']}";
		fi
	fi
}


function start_printer (){
		if [[ ${KASM_SVC_PRINTER:-1} == 1 ]]; then
			echo 'Starting printer service'
            if [[ $DEBUG == true ]]; then
			    $STARTUPDIR/printer/kasm_printer_service --debug --directory $HOME/PDF --relay /tmp/printer &
		    else
			    $STARTUPDIR/printer/kasm_printer_service --directory $HOME/PDF --relay /tmp/printer &
		    fi

		KASM_PROCS['kasm_printer']=$!

		if [[ $DEBUG == true ]]; then
			echo -e "\n------------------ Started Printer Service  ----------------------------"
			echo "Kasm Printer PID: ${KASM_PROCS['kasm_printer']}";
		fi
	fi
}


function start_discord_rich_presence (){
	if [[ ${KASM_SVC_DISCORD_RPC:-1} == 1 ]]; then
		echo 'Starting Discord Rich Presence for Plex'

		# Check if Discord RPC is already running
		if ! pgrep -f "discord-rich-presence-plex" > /dev/null; then
			# Create DRPP config directory if it doesn't exist
			mkdir -p $HOME/.config/discord-rich-presence-plex

			# Source DRPP environment if it exists
			if [ -f "$HOME/.config/discord-rich-presence-plex/env" ]; then
				source "$HOME/.config/discord-rich-presence-plex/env"
			fi

			# Start DRPP in background
			python3 /opt/discord-rich-presence-plex/main.py &
			KASM_PROCS['discord_rpc']=$!

			if [[ $DEBUG == true ]]; then
				echo -e "\n------------------ Started Discord Rich Presence for Plex  ----------------------------"
				echo "Discord RPC PID: ${KASM_PROCS['discord_rpc']}";
			fi
		else
			echo "Discord Rich Presence already running"
			EXISTING_PID=$(pgrep -f "discord-rich-presence-plex" | head -1)
			if [[ -n "$EXISTING_PID" ]]; then
				KASM_PROCS['discord_rpc']=$EXISTING_PID
			fi
		fi
	fi
}

function custom_startup (){
	custom_startup_script=/dockerstartup/custom_startup.sh
	if [ -f "$custom_startup_script" ]; then
		if [ ! -x "$custom_startup_script" ]; then
			echo "${custom_startup_script}: not executable, exiting"
			exit 1
		fi

		"$custom_startup_script" &
		KASM_PROCS['custom_startup']=$!
	fi
}

############ END FUNCTION DECLARATIONS ###########

if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

if [[ ${KASM_DEBUG:-0} == 1 ]]; then
    echo -e "\n\n------------------ DEBUG KASM STARTUP -----------------"
    export DEBUG=true
    set -x
fi

# Syncronize user-space loaded persistent profiles
pull_profile

# should also source $STARTUPDIR/generate_container_user
if [ -f $HOME/.bashrc ]; then
    source $HOME/.bashrc
fi

## resolve_vnc_connection
VNC_IP=$(hostname -i)
if [[ $DEBUG == true ]]; then
    echo "IP Address used for external bind: $VNC_IP"
fi

# Set up DBus session address for Flatpak and other services
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
if [[ $DEBUG == true ]]; then
    echo "DBus session bus address: $DBUS_SESSION_BUS_ADDRESS"
fi

# Create cert for KasmVNC with proper CN=localhost and SANs
# Delete old cert to force regeneration with correct parameters
mkdir -p ${HOME}/.vnc
rm -f ${HOME}/.vnc/self.pem

# Generate SSL certificate with CN=localhost (for internal connections) and SANs for all hostnames
# The certificate needs to work for:
# 1. External: discord.xxx.com (through nginx)
# 2. Internal: kasmdiscordplexcontrol (nginx upstream), localhost, 127.0.0.1 (local connections)
echo "Generating SSL certificate with SANs for all connection methods..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ${HOME}/.vnc/self.pem -out ${HOME}/.vnc/self.pem \
    -subj "/C=US/ST=VA/L=None/O=None/OU=Plex/CN=kasmdiscordplexcontrol/emailAddress=none@none.none" \
    -addext "subjectAltName=DNS:kasmdiscordplexcontrol,DNS:discord.xxx.com,DNS:localhost,DNS:127.0.0.1,IP:127.0.0.1" 2>&1
chmod 600 ${HOME}/.vnc/self.pem
echo "SSL certificate generated at ${HOME}/.vnc/self.pem"

# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.kasmpasswd"
if [[ -f $PASSWD_PATH ]]; then
    echo -e "\n---------  purging existing VNC password settings  ---------"
    rm -f $PASSWD_PATH
fi
#VNC_PW_HASH=$(python3 -c "import crypt; print(crypt.crypt('${VNC_PW}', '\$5\$kasm\$'));")
#VNC_VIEW_PW_HASH=$(python3 -c "import crypt; print(crypt.crypt('${VNC_VIEW_ONLY_PW}', '\$5\$kasm\$'));")
#echo "kasm_user:${VNC_PW_HASH}:ow" > $PASSWD_PATH
#echo "kasm_viewer:${VNC_VIEW_PW_HASH}:" >> $PASSWD_PATH
echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u kasm_user -wo
echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u kasm_viewer -r
chmod 600 $PASSWD_PATH

# --- FIX AUDIO / START PIPEWIRE EARLY ---
export XDG_RUNTIME_DIR="/tmp/runtime-kasm-user"
export PULSE_RUNTIME_PATH="/tmp/runtime-kasm-user/pulse"
export PIPEWIRE_RUNTIME_DIR="/tmp/runtime-kasm-user"
mkdir -p "$PULSE_RUNTIME_PATH"

# Ensure proper permissions for audio/pipewire directories
chmod 755 /tmp 2>/dev/null || true
mkdir -p /tmp/pipewire-0 2>/dev/null || true
chmod 755 /tmp/pipewire-0 2>/dev/null || true
chmod 755 "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 755 "$PULSE_RUNTIME_PATH" 2>/dev/null || true
chown -R 1000:0 "$XDG_RUNTIME_DIR" 2>/dev/null || true

sleep 1  # allow time to create pulse socket

# start processes
start_kasmvnc
start_window_manager
start_audio_out_websocket
start_audio_out
start_audio_in
start_upload
start_gamepad
profile_size_check &
start_webcam
start_printer
#start_discord_rich_presence


STARTUP_COMPLETE=1


## log connect options
echo -e "\n\n------------------ KasmVNC environment started ------------------"

# tail vncserver logs
tail -f $HOME/.vnc/*$DISPLAY.log &

KASMIP=$(hostname -i)
echo "Kasm User ${KASM_USER}(${KASM_USER_ID}) started container id ${HOSTNAME} with local IP address ${KASMIP}"

# start custom startup script
custom_startup

# Monitor Kasm Services
sleep 3
while :
do
	for process in "${!KASM_PROCS[@]}"; do
		# Skip if PID is empty or invalid
		if [[ -z "${KASM_PROCS[$process]}" ]] || [[ ! "${KASM_PROCS[$process]}" =~ ^[0-9]+$ ]]; then
			echo "Invalid PID for $process: ${KASM_PROCS[$process]}, skipping check"
			continue
		fi
		
		if ! kill -0 "${KASM_PROCS[$process]}" 2>/dev/null ; then

			# If DLP Policy is set to fail secure, default is to be resilient
			if [[ ${DLP_PROCESS_FAIL_SECURE:-0} == 1 ]]; then
				exit 1
			fi

			case $process in
				kasmvnc)
					if [ "$KASMVNC_AUTO_RECOVER" = true ] ; then
						echo "KasmVNC crashed, restarting"
						start_kasmvnc
						sleep 2
					else
						echo "KasmVNC crashed, exiting container"
						exit 1
					fi
					;;
				window_manager)
					echo "Window manager crashed, restarting"
					start_window_manager
					sleep 2
					;;
				kasm_audio_out_websocket)
					echo "Restarting Audio Out Websocket Service"
					start_audio_out_websocket
					sleep 1
					;;
				kasm_audio_out)
					echo "Restarting Audio Out Service"
					# First check if ffmpeg is actually still running
					if pgrep -f "ffmpeg.*kasmaudio" > /dev/null; then
						echo "Audio streaming process is still running, updating PID"
						EXISTING_PID=$(pgrep -f "ffmpeg.*kasmaudio" | head -1)
						if [[ -n "$EXISTING_PID" ]]; then
							KASM_PROCS['kasm_audio_out']=$EXISTING_PID
							echo "Updated Audio Out PID: ${KASM_PROCS['kasm_audio_out']}"
						else
							echo "Could not get valid PID, restarting service"
							start_audio_out
							sleep 2
						fi
					else
						echo "Audio streaming process not found, restarting"
						start_audio_out
						sleep 2
					fi
					;;
				kasm_audio_in)
					echo "Audio In Service Failed"
					# TODO: Needs work in python project to support auto restart
					# start_audio_in
					;;
				upload_server)
					echo "Restarting Upload Service"
					# TODO: This will only work if both processes are killed, requires more work
					start_upload
					sleep 1
					;;
                                kasm_gamepad)
					echo "Gamepad Service Failed"
					# TODO: Needs work in python project to support auto restart
					# start_gamepad
					;;
				kasm_webcam)
					echo "Webcam Service Failed"
					# TODO: Needs work in python project to support auto restart
					start_webcam
					sleep 1
					;;
				kasm_printer)
					echo "Printer Service Failed"
					# TODO: Needs work in python project to support auto restart
					start_printer
					sleep 1
					;;
				discord_rpc)
					echo "Discord Rich Presence Service Failed, restarting"
					start_discord_rich_presence
					sleep 2
					;;
				custom_script)
					echo "The custom startup script exited."
					# custom startup scripts track the target process on their own, they should not exit
					custom_startup
					sleep 1
					;;
				*)
					echo "Unknown Service: $process"
					;;
			esac
		fi
	done
	sleep 3
done

# Keep the container running indefinitely
echo "Kasm container is running. Press Ctrl+C to stop."
while true; do
	sleep 3600
done