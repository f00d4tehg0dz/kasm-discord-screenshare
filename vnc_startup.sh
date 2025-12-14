#!/bin/bash
### every exit != 0 fails the script
set -e

no_proxy="localhost,127.0.0.1"

# dict to store processes - REQUIRED for KASM_PROCS associative array
declare -A KASM_PROCS

# Create Discord IPC socket directory for rich presence
mkdir -p /tmp/runtime-kasm-user/discord-ipc-0 2>/dev/null || true
chmod 755 /tmp/runtime-kasm-user/discord-ipc-0 2>/dev/null || true


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


	if [[ $DEBUG == true ]]; then
	  echo -e "\n------------------ Started Websockify  ----------------------------"
	  echo "Websockify PID: ${KASM_PROCS['kasmvnc']}";
	fi
}

function custom_startup_discord (){
	custom_startup_discord=/dockerstartup/custom_startup.sh
	if [ -f "$custom_startup_discord" ]; then
		if [ ! -x "$custom_startup_discord" ]; then
			echo "${custom_startup_discord}: not executable, exiting"
			exit 1
		fi
	}

function custom_startup_plex_discord (){
	custom_startup_script=/dockerstartup/custom_startup-plex-discord.sh
	if [ -f "$custom_startup_script" ]; then
		if [ ! -x "$custom_startup_script" ]; then
			echo "${custom_startup_script}: not executable, exiting"
			exit 1
		fi

		"$custom_startup_script" &
		KASM_PROCS['custom_startup_plex_discord']=$!
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

# Create cert for KasmVNC with proper CN=localhost and SANs
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

echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u kasm_user -wo
echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u kasm_viewer -r
chmod 600 $PASSWD_PATH

STARTUP_COMPLETE=1

## log connect options
echo -e "\n\n------------------ KasmVNC environment started ------------------"

# tail vncserver logs
tail -f $HOME/.vnc/*$DISPLAY.log &

KASMIP=$(hostname -i)
echo "Kasm User ${KASM_USER}(${KASM_USER_ID}) started container id ${HOSTNAME} with local IP address ${KASMIP}"

# start custom startup script
custom_startup_plex_discord
custom_startup_discord
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
				custom_script)
					echo "The custom startup script exited."
					# custom startup scripts track the target process on their own, they should not exit
					custom_startup_plex_discord
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

echo "Kasm container monitoring loop ended unexpectedly"