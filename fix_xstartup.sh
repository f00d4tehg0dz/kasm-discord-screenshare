#!/bin/bash
# Create a temp file
TMPFILE="/tmp/vnc_startup_fixed.sh"

# Find the line numbers
START_LINE=$(grep -n "# Log startup for debugging" vnc_startup.sh | head -1 | cut -d: -f1)
END_LINE=$(grep -n "sleep infinity" vnc_startup.sh | grep -v "# Keep" | tail -1 | cut -d: -f1)
XSTARTUP_START=$(grep -n "cat > \$HOME/.vnc/xstartup" vnc_startup.sh | cut -d: -f1)
XSTARTUP_END=$(grep -n "^XSTARTUP" vnc_startup.sh | cut -d: -f1)

echo "DEBUG: XSTARTUP_START=$XSTARTUP_START, XSTARTUP_END=$XSTARTUP_END"
echo "DEBUG: START_LINE=$START_LINE, END_LINE=$END_LINE"

if [ -z "$XSTARTUP_START" ] || [ -z "$XSTARTUP_END" ]; then
    echo "ERROR: Could not find XSTARTUP markers"
    exit 1
fi

# Extract parts before XSTARTUP
head -n $((XSTARTUP_START + 6)) vnc_startup.sh > "$TMPFILE"

# Add the simplified xstartup
cat >> "$TMPFILE" << 'NEWXSTARTUP'
# Start XFCE4 desktop environment
if [ -x /usr/bin/startxfce4 ]; then
    /usr/bin/startxfce4 --replace
else
    # Fallback to xterm if startxfce4 not available
    xterm &
fi
NEWXSTARTUP

# Add the rest after XSTARTUP
tail -n +$((XSTARTUP_END + 1)) vnc_startup.sh >> "$TMPFILE"

# Replace original
mv "$TMPFILE" vnc_startup.sh
echo "Successfully simplified xstartup script"
