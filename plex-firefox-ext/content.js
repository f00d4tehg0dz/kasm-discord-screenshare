console.log('[Plex Discord] Content script loaded on', window.location.href);

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.type === 'plex_command') {
    const cmd = request.command;
    console.log('[Plex Discord] Processing command:', cmd.action);

    try {
      const getPlayer = () => document.querySelector('video') || document.querySelector('[class*="player"]');

      const handlePlay = (cmd) => {
        const video = getPlayer();
        if (video && video.play) {
          video.play();
          console.log('[Plex Discord] Playing');
        }
      };

      const handlePause = () => {
        const video = getPlayer();
        if (video && video.pause) {
          video.pause();
          console.log('[Plex Discord] Paused');
        }
      };

      const handleTogglePlay = () => {
        const video = getPlayer();
        if (video) {
          if (video.paused) {
            video.play();
          } else {
            video.pause();
          }
          console.log('[Plex Discord] Toggled play state');
        }
      };

      const handleSeek = (seconds) => {
        const video = getPlayer();
        if (video) {
          video.currentTime = Math.max(0, video.currentTime + seconds);
          console.log('[Plex Discord] Seeked to', video.currentTime);
        }
      };

      const handleSearch = (query) => {
        const searchBtn = document.querySelector('[aria-label*="search"], [class*="search"]');
        if (searchBtn) {
          searchBtn.click();
          setTimeout(() => {
            const searchInput = document.querySelector('input[placeholder*="search"], input[type="search"]');
            if (searchInput) {
              searchInput.focus();
              searchInput.value = query;
              searchInput.dispatchEvent(new Event('input', {bubbles: true}));
              searchInput.dispatchEvent(new Event('change', {bubbles: true}));
              console.log('[Plex Discord] Searching for:', query);
            }
          }, 500);
        }
      };

      const handleVolume = (value) => {
        const video = getPlayer();
        if (video) {
          video.volume = Math.max(0, Math.min(1, value / 100));
          console.log('[Plex Discord] Volume set to', video.volume * 100);
        }
      };

      const handleNext = () => {
        // Try multiple selectors for the next button in Plex web player
        const nextSelectors = [
          // Exact match for Plex web player
          'button[aria-label="Next"]',
          'button[aria-label="Skip Forward 30 Seconds"]',
          // Partial matches (case-insensitive)
          'button[aria-label*="Next"]',
          'button[aria-label*="next"]',
          'button[aria-label*="Skip"]',
          'button[aria-label*="skip"]',
          'button[aria-label*="Forward"]',
          'button[aria-label*="forward"]',
          // Generic button patterns
          'button[class*="NextButton"]',
          'button[class*="SkipButton"]',
          'button[title*="Next"]',
          'button[title*="Skip"]',
          'button[title*="Forward"]',
          // SVG-based buttons
          'button:has(svg[class*="skip"])',
          'button:has(svg[class*="forward"])',
          // Plex specific
          '[role="button"][aria-label*="next"]',
          '[role="button"][aria-label*="skip"]',
        ];

        let nextBtn = null;
        for (let selector of nextSelectors) {
          try {
            nextBtn = document.querySelector(selector);
            if (nextBtn) {
              console.log('[Plex Discord] Found next button with selector:', selector);
              break;
            }
          } catch (e) {
            // Some selectors might fail, continue to next
          }
        }

        if (nextBtn && nextBtn.offsetHeight > 0) { // Check if button is visible
          console.log('[Plex Discord] Clicking next button');
          try {
            // Try multiple click approaches for React-based UI
            nextBtn.focus();
            nextBtn.click();
            nextBtn.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true}));
            nextBtn.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, cancelable: true}));
            nextBtn.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));

            // Also try the pointer events (more modern)
            nextBtn.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true, cancelable: true}));
            nextBtn.dispatchEvent(new PointerEvent('pointerup', {bubbles: true, cancelable: true}));

            console.log('[Plex Discord] Clicked next button with multiple event approaches');

            // Give it a moment to process, then try keyboard as fallback
            setTimeout(() => {
              const video = getPlayer();
              if (video && video.currentTime === video.currentTime) { // Check if playback hasn't changed
                console.log('[Plex Discord] Click may not have worked, trying keyboard fallback');
                tryKeyboardNext();
              }
            }, 500);
          } catch (e) {
            console.error('[Plex Discord] Error clicking next button:', e);
            // Try keyboard fallback
            tryKeyboardNext();
          }
        } else {
          console.warn('[Plex Discord] Could not find visible next button, trying keyboard shortcut');
          tryKeyboardNext();
        }

        function tryKeyboardNext() {
          const video = getPlayer();

          // Try keyboard events on multiple targets
          const targets = [document.body, document.documentElement, video];
          let eventSent = false;

          for (let target of targets) {
            if (!target) continue;
            try {
              // Try right arrow key
              const rightArrowEvent = new KeyboardEvent('keydown', {
                key: 'ArrowRight',
                code: 'ArrowRight',
                keyCode: 39,
                bubbles: true,
                cancelable: true
              });
              target.dispatchEvent(rightArrowEvent);
              console.log('[Plex Discord] Sent ArrowRight key event to', target.nodeName);
              eventSent = true;
              break;
            } catch (e) {
              console.debug('[Plex Discord] Failed to dispatch to', target.nodeName, e.message);
            }
          }

          if (!eventSent && video) {
            // Last resort: seek forward 30 seconds
            try {
              video.currentTime = Math.min(video.duration, video.currentTime + 30);
              console.log('[Plex Discord] Seeked forward 30 seconds');
            } catch (e) {
              console.error('[Plex Discord] Failed to seek forward:', e.message);
            }
          }
        }
      };

      const handlePrevious = () => {
        // Try multiple selectors for the previous button in Plex web player
        const prevSelectors = [
          // Exact match for Plex web player
          'button[aria-label="Previous"]',
          'button[aria-label="Skip Back 10 Seconds"]',
          // Partial matches (case-insensitive)
          'button[aria-label*="Previous"]',
          'button[aria-label*="previous"]',
          'button[aria-label*="Back"]',
          'button[aria-label*="back"]',
          'button[aria-label*="Rewind"]',
          'button[aria-label*="rewind"]',
          // Generic button patterns
          'button[class*="PreviousButton"]',
          'button[class*="BackButton"]',
          'button[class*="RewindButton"]',
          'button[title*="Previous"]',
          'button[title*="Back"]',
          'button[title*="Rewind"]',
          // SVG-based buttons
          'button:has(svg[class*="back"])',
          'button:has(svg[class*="rewind"])',
          // Plex specific
          '[role="button"][aria-label*="previous"]',
          '[role="button"][aria-label*="back"]',
          '[role="button"][aria-label*="rewind"]',
        ];

        let prevBtn = null;
        for (let selector of prevSelectors) {
          try {
            prevBtn = document.querySelector(selector);
            if (prevBtn) {
              console.log('[Plex Discord] Found previous button with selector:', selector);
              break;
            }
          } catch (e) {
            // Some selectors might fail, continue to next
          }
        }

        if (prevBtn && prevBtn.offsetHeight > 0) { // Check if button is visible
          console.log('[Plex Discord] Clicking previous button');
          try {
            // Try multiple click approaches for React-based UI
            prevBtn.focus();
            prevBtn.click();
            prevBtn.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true}));
            prevBtn.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, cancelable: true}));
            prevBtn.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));

            // Also try the pointer events (more modern)
            prevBtn.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true, cancelable: true}));
            prevBtn.dispatchEvent(new PointerEvent('pointerup', {bubbles: true, cancelable: true}));

            console.log('[Plex Discord] Clicked previous button with multiple event approaches');

            // Give it a moment to process, then try keyboard as fallback
            setTimeout(() => {
              const video = getPlayer();
              if (video && video.currentTime === video.currentTime) { // Check if playback hasn't changed
                console.log('[Plex Discord] Click may not have worked, trying keyboard fallback');
                tryKeyboardPrevious();
              }
            }, 500);
          } catch (e) {
            console.error('[Plex Discord] Error clicking previous button:', e);
            // Try keyboard fallback
            tryKeyboardPrevious();
          }
        } else {
          console.warn('[Plex Discord] Could not find visible previous button, trying keyboard shortcut');
          tryKeyboardPrevious();
        }

        function tryKeyboardPrevious() {
          const video = getPlayer();

          // Try keyboard events on multiple targets
          const targets = [document.body, document.documentElement, video];
          let eventSent = false;

          for (let target of targets) {
            if (!target) continue;
            try {
              // Try left arrow key
              const leftArrowEvent = new KeyboardEvent('keydown', {
                key: 'ArrowLeft',
                code: 'ArrowLeft',
                keyCode: 37,
                bubbles: true,
                cancelable: true
              });
              target.dispatchEvent(leftArrowEvent);
              console.log('[Plex Discord] Sent ArrowLeft key event to', target.nodeName);
              eventSent = true;
              break;
            } catch (e) {
              console.debug('[Plex Discord] Failed to dispatch to', target.nodeName, e.message);
            }
          }

          if (!eventSent && video) {
            // Last resort: seek backward 30 seconds
            try {
              video.currentTime = Math.max(0, video.currentTime - 30);
              console.log('[Plex Discord] Seeked backward 30 seconds');
            } catch (e) {
              console.error('[Plex Discord] Failed to seek backward:', e.message);
            }
          }
        }
      };

      const handleFullscreen = () => {
        const video = getPlayer();
        if (video && video.requestFullscreen) {
          video.requestFullscreen();
          console.log('[Plex Discord] Fullscreen toggled');
        }
      };

      const handleGetStatus = () => {
        const video = getPlayer();
        if (video) {
          const status = {
            playing: !video.paused,
            currentTime: video.currentTime,
            duration: video.duration,
            volume: video.volume,
            title: document.title
          };
          browser.runtime.sendMessage({type: 'playback_status', status: status});
          console.log('[Plex Discord] Status:', status);
        }
      };

      const handlePlayMedia = (cmd) => {
        const params = cmd.params || {};
        const key = params.key;
        const containerKey = params.containerKey;

        console.log('[Plex Discord] PlayMedia command received');
        console.log('[Plex Discord] Key:', key);
        console.log('[Plex Discord] Container Key:', containerKey);
        console.log('[Plex Discord] Full params:', params);

        if (!key) {
          console.error('[Plex Discord] No key provided for playMedia');
          sendResponse({status: 'error', message: 'No key provided'});
          return;
        }

        try {
          // Log the raw key value for debugging
          console.log('[Plex Discord] Raw key value:', key);
          console.log('[Plex Discord] Params received:', JSON.stringify(params, null, 2));

          // Extract server ID - first try from params (sent by Discord bot), then from current URL hash
          let serverId = params.serverId;  // Discord bot can send the server ID from Plex identity API

          // If not provided in params, try to extract from current URL hash
          if (!serverId) {
            const currentHash = window.location.hash;
            const serverMatch = currentHash.match(/#!\/server\/([^/]+)/);
            if (serverMatch) {
              serverId = serverMatch[1];
              console.log('[Plex Discord] Extracted server ID from current URL:', serverId);
            }
          } else {
            console.log('[Plex Discord] Using server ID from params:', serverId);
          }

          // If we couldn't get server ID, we cannot proceed
          if (!serverId) {
            console.error('[Plex Discord] Server ID is required for playback. Params:', params);
            sendResponse({status: 'error', message: 'No server ID available for playback'});
            return;
          }

          // Extract context parameter from current URL if available (maintains library context)
          let contextParam = '';
          const currentHash = window.location.hash;
          const contextMatch = currentHash.match(/context=([^&]+)/);
          if (contextMatch) {
            contextParam = `&context=${contextMatch[1]}`;
            console.log('[Plex Discord] Preserved context parameter:', contextParam);
          }

          // Construct Plex web navigation URL using hash format
          // Format: #!/server/{serverId}/details?key={key}&context={context}
          // The key and context should be URL-encoded
          const detailsUrl = `#!/server/${serverId}/details?key=${encodeURIComponent(key)}${contextParam}`;
          console.log('[Plex Discord] Navigating to:', detailsUrl);
          console.log('[Plex Discord] Full URL will be:', window.location.origin + window.location.pathname + detailsUrl);

          // Navigate to the media details page
          window.location.hash = detailsUrl;

          // Wait for the page to load and then click the play button
          let retries = 0;
          const maxRetries = 60; // 60 attempts * 200ms = 12 seconds max
          const playbackInterval = setInterval(() => {
            retries++;

            if (retries % 5 === 0) { // Log every 5th attempt to reduce spam
              console.log(`[Plex Discord] Playback attempt ${retries}/${maxRetries}, current hash: ${window.location.hash}`);
            }

            // Try to find and click the play button in the Plex UI
            // First try the specific Plex data-testid for the preplay button
            let playButton = document.querySelector('button[data-testid="preplay-play"]');

            // If not found, try other selectors
            if (!playButton) {
              playButton = document.querySelector('button[aria-label="Play"]') ||
                          document.querySelector('[class*="PlayerIconButton-isPrimary"][aria-label*="Pause"]')?.parentElement?.querySelector('button[aria-label*="Play"]') ||
                          Array.from(document.querySelectorAll('button')).find(btn => {
                            const label = btn.getAttribute('aria-label') || btn.title || btn.textContent;
                            return label && label.includes('Play') && btn.offsetHeight > 0;
                          });
            }

            if (playButton && playButton.offsetHeight > 0) {
              console.log('[Plex Discord] Play button found, clicking it');
              try {
                playButton.focus();
                playButton.click();
                playButton.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true}));
                playButton.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, cancelable: true}));
                playButton.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
                playButton.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true, cancelable: true}));
                playButton.dispatchEvent(new PointerEvent('pointerup', {bubbles: true, cancelable: true}));
                console.log('[Plex Discord] Play button clicked successfully');
                clearInterval(playbackInterval);
              } catch (e) {
                console.error('[Plex Discord] Error clicking play button:', e.message);
              }
            } else if (retries >= maxRetries) {
              console.warn('[Plex Discord] Play button not found after 12 seconds, giving up on playback');
              console.warn('[Plex Discord] This may indicate the media key is invalid or Plex cannot find the content');
              clearInterval(playbackInterval);
            }
          }, 200);

        } catch (e) {
          console.error('[Plex Discord] PlayMedia error:', e);
          sendResponse({status: 'error', message: e.message});
          return;
        }
      };

      switch (cmd.action) {
        case 'playMedia':
          handlePlayMedia(cmd);
          break;
        case 'play':
          handlePlay(cmd);
          break;
        case 'pause':
          handlePause();
          break;
        case 'toggle_play':
          handleTogglePlay();
          break;
        case 'seek':
          handleSeek(cmd.value);
          break;
        case 'search':
          handleSearch(cmd.content);
          break;
        case 'volume':
          handleVolume(cmd.value);
          break;
        case 'next':
          handleNext();
          break;
        case 'previous':
          handlePrevious();
          break;
        case 'fullscreen':
          handleFullscreen();
          break;
        case 'status':
          handleGetStatus();
          break;
        default:
          console.warn('[Plex Discord] Unknown action:', cmd.action);
      }

      // Send response with id from the command so background script can relay it back
      const response = {status: 'ok'};
      if (cmd.id) response.id = cmd.id;
      sendResponse(response);
    } catch (e) {
      console.error('[Plex Discord] Command error:', e);
      sendResponse({status: 'error', message: e.message});
    }
  }

  return true;
});

// Debug helper to inspect player controls
function debugPlayerControls() {
  const video = document.querySelector('video');
  const playerDiv = document.querySelector('[class*="player"]');

  console.log('[Plex Discord] === PLAYER DEBUG INFO ===');
  console.log('[Plex Discord] Video element found:', !!video);
  console.log('[Plex Discord] Player div found:', !!playerDiv);

  // Find all buttons
  const allButtons = document.querySelectorAll('button');
  console.log('[Plex Discord] Total buttons on page:', allButtons.length);

  // Log buttons with aria-labels
  const labeledButtons = Array.from(allButtons).filter(b => b.getAttribute('aria-label'));
  console.log('[Plex Discord] Buttons with aria-labels:');
  labeledButtons.slice(0, 20).forEach((btn, idx) => {
    console.log(`  ${idx}: "${btn.getAttribute('aria-label')}" - visible: ${btn.offsetHeight > 0}`);
  });

  // Look for specific control buttons
  const controlsContainer = document.querySelector('[class*="player-controls"], [class*="Controls"], [data-testid*="controls"]');
  if (controlsContainer) {
    console.log('[Plex Discord] Found controls container:', controlsContainer.className);
    const controlButtons = controlsContainer.querySelectorAll('button');
    console.log('[Plex Discord] Buttons in controls:', controlButtons.length);
    Array.from(controlButtons).slice(0, 10).forEach((btn, idx) => {
      console.log(`  ${idx}: class="${btn.className}" aria-label="${btn.getAttribute('aria-label')}"`);
    });
  }
}

// Run debug on page load and periodically
setTimeout(debugPlayerControls, 1000);
setInterval(debugPlayerControls, 10000);

setTimeout(() => {
  browser.runtime.sendMessage({type: 'status', status: 'content_ready'}).catch(() => {});
}, 500);
