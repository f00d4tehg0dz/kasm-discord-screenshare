// Connect to the local WebSocket server (port configurable via environment/storage)
// Port 10009: Plain WS for browser clients (Firefox extension) - default
// Port 10100: SSL WSS for Discord bot connections
// Both instances share state through a shared Unix socket IPC mechanism

// Get WebSocket URL from storage or use default
let WS_URL = 'ws://localhost:10009/browser';
let ws = null;
let reconnectAttempts = 0;
let MAX_RECONNECT_ATTEMPTS = 5;
let RECONNECT_DELAY = 3000;
let heartbeatInterval = null;
let HEARTBEAT_INTERVAL = 30000; // Send heartbeat every 30 seconds (configurable)

// Initialize configuration from storage
async function initializeConfig() {
  try {
    const stored = await browser.storage.local.get(['WS_URL', 'MAX_RECONNECT_ATTEMPTS', 'RECONNECT_DELAY', 'HEARTBEAT_INTERVAL']);

    if (stored.WS_URL) {
      WS_URL = stored.WS_URL;
      console.log('[Plex Discord] Using stored WebSocket URL:', WS_URL);
    } else {
      // Check if running in Kasm container (localhost) or external (use container IP)
      const isLocalhost = window.location.hostname === 'localhost' ||
                         window.location.hostname === '127.0.0.1' ||
                         window.location.hostname.includes('192.168');
      if (isLocalhost) {
        WS_URL = 'ws://localhost:10009/browser';
      } else {
        // For external access, try to determine the internal IP
        WS_URL = 'ws://localhost:10009/browser'; // Fallback, should be configured
      }
      console.log('[Plex Discord] Using default WebSocket URL:', WS_URL);
    }

    if (stored.MAX_RECONNECT_ATTEMPTS) {
      MAX_RECONNECT_ATTEMPTS = stored.MAX_RECONNECT_ATTEMPTS;
    }
    if (stored.RECONNECT_DELAY) {
      RECONNECT_DELAY = stored.RECONNECT_DELAY;
    }
    if (stored.HEARTBEAT_INTERVAL) {
      HEARTBEAT_INTERVAL = stored.HEARTBEAT_INTERVAL;
    }

    connectWebSocket();
  } catch (e) {
    console.error('[Plex Discord] Failed to initialize config:', e);
    connectWebSocket(); // Try with defaults
  }
}

async function injectContentScriptToAllPlexTabs() {
  try {
    const tabs = await browser.tabs.query({url: ['*://*/web*', '*://*:32400/*']});
    for (let tab of tabs) {
      try {
        console.log('[Plex Discord] Injecting content script to tab', tab.id, ':', tab.url);
        await browser.scripting.executeScript({
          target: { tabId: tab.id },
          files: ['content.js']
        });
        console.log('[Plex Discord] Content script injected to tab', tab.id);
      } catch (err) {
        console.debug('[Plex Discord] Could not inject content script to tab', tab.id, ':', err.message);
      }
    }
  } catch (err) {
    console.debug('[Plex Discord] Error finding Plex tabs:', err.message);
  }
}

function connectWebSocket() {
  try {
    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
      console.log('[Plex Discord] WebSocket connected');
      reconnectAttempts = 0;
      browser.runtime.sendMessage({type: 'status', status: 'connected'}).catch(() => {});

      // Inject content script to all Plex tabs
      injectContentScriptToAllPlexTabs();

      // Start heartbeat to keep connection alive
      if (heartbeatInterval) clearInterval(heartbeatInterval);
      heartbeatInterval = setInterval(() => {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({type: 'heartbeat'}));
          console.log('[Plex Discord] Sent heartbeat');
        }
      }, HEARTBEAT_INTERVAL);
    };

    ws.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);

        // Handle different message types from server
        if (message.type === 'ready') {
          console.log('[Plex Discord] Server ready:', message.message);
          return;
        }

        // Only process messages with an action (actual commands from Discord bot)
        if (!message.action) {
          console.debug('[Plex Discord] Ignoring message without action:', message);
          return;
        }

        console.log('[Plex Discord] Received command:', message.action);

        browser.tabs.query({url: ['*://*/web*', '*://*:32400/*']}).then(async (tabs) => {
          if (tabs.length === 0) {
            console.warn('[Plex Discord] No Plex tabs found to send command to');
            // Send error response back to WebSocket server
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({id: message.id, status: 'error', error: 'No Plex tabs found'}));
            }
            return;
          }
          console.log('[Plex Discord] Found', tabs.length, 'Plex tab(s)');
          let commandSent = false;
          for (let tab of tabs) {
            console.log('[Plex Discord] Processing tab:', tab.url);
            try {
              // First ensure content script is injected
              console.log('[Plex Discord] Injecting content script to tab', tab.id);
              await browser.scripting.executeScript({
                target: { tabId: tab.id },
                files: ['content.js']
              });
              console.log('[Plex Discord] Content script injected to tab', tab.id);

              // Now send the message and wait for response
              console.log('[Plex Discord] Sending command to tab', tab.id);
              try {
                const response = await browser.tabs.sendMessage(tab.id, {type: 'plex_command', command: message});
                console.log('[Plex Discord] Command processed by tab', tab.id, ':', response);
                commandSent = true;

                // Send success response back to WebSocket server
                if (ws && ws.readyState === WebSocket.OPEN) {
                  ws.send(JSON.stringify({id: message.id, status: 'ok', message: 'Command executed'}));
                }
                break; // Stop after first successful tab
              } catch (sendErr) {
                console.error('[Plex Discord] Failed to send message to tab', tab.id, ':', sendErr.message);
              }
            } catch (injectErr) {
              console.error('[Plex Discord] Failed to inject content script to tab', tab.id, ':', injectErr.message);
            }
          }

          // If no tab processed the command, send error response
          if (!commandSent && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({id: message.id, status: 'error', error: 'Failed to execute command on any tab'}));
          }
        });
      } catch (e) {
        console.error('[Plex Discord] Parse error:', e);
      }
    };

    ws.onerror = (error) => {
      console.error('[Plex Discord] WebSocket error:', error);
    };

    ws.onclose = () => {
      console.log('[Plex Discord] WebSocket closed');
      // Stop heartbeat
      if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
      }
      attemptReconnect();
    };
  } catch (e) {
    console.error('[Plex Discord] Connection failed:', e);
    attemptReconnect();
  }
}

function attemptReconnect() {
  if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    reconnectAttempts++;
    console.log('[Plex Discord] Reconnect attempt ' + reconnectAttempts + '/' + MAX_RECONNECT_ATTEMPTS);
    setTimeout(connectWebSocket, RECONNECT_DELAY);
  } else {
    console.error('[Plex Discord] Max reconnection attempts reached');
  }
}

browser.runtime.onMessage.addListener((request) => {
  if (request.type === 'playback_status') {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({type: 'status', status: request.status}));
    }
  }
});

// Initialize configuration and start connection
initializeConfig();