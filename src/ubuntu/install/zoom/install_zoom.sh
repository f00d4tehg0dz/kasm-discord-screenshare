#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi

# Install Zoom
wget -q  https://zoom.us/client/latest/zoom_${ARCH}.deb
apt-get update
apt-get install -y ./zoom_${ARCH}.deb
rm zoom_amd64.deb
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop

# Add wrapper to detect seccomp
rm -f /usr/bin/zoom
cat > /usr/bin/zoom <<EOF
#!/bin/bash
if [[ \$(awk '/Seccomp:/ {print \$2}' /proc/1/status) == "0" ]]; then
  /opt/zoom/ZoomLauncher "\$@"
else
  /opt/zoom/ZoomLauncher --no-sandbox "\$@"
fi
EOF
chmod +x /usr/bin/zoom

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
