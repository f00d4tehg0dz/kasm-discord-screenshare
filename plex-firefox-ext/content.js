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
        // First try to click the next button if it exists
        let nextBtn = document.querySelector('[data-testid="nextButton"]');
        if (!nextBtn) {
          nextBtn = document.querySelector('[aria-label*="next"]');
        }
        if (!nextBtn) {
          nextBtn = document.querySelector('[class*="Next"]');
        }

        if (nextBtn) {
          console.log('[Plex Discord] Found next button, clicking it');
          // Try multiple click approaches to bypass event handlers
          nextBtn.click();
          nextBtn.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
          console.log('[Plex Discord] Skipped to next');
        } else {
          console.warn('[Plex Discord] Could not find next button, trying seek approach');
          // Fallback: seek forward 30 seconds if button not found
          const video = getPlayer();
          if (video) {
            video.currentTime = Math.min(video.duration, video.currentTime + 30);
            console.log('[Plex Discord] Seeked forward 30 seconds');
          }
        }
      };

      const handlePrevious = () => {
        // First try to click the previous button if it exists
        let prevBtn = document.querySelector('[data-testid="previousButton"]');
        if (!prevBtn) {
          prevBtn = document.querySelector('[aria-label*="previous"]');
        }
        if (!prevBtn) {
          prevBtn = document.querySelector('[class*="Previous"]');
        }

        if (prevBtn) {
          console.log('[Plex Discord] Found previous button, clicking it');
          // Try multiple click approaches to bypass event handlers
          prevBtn.click();
          prevBtn.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
          console.log('[Plex Discord] Skipped to previous');
        } else {
          console.warn('[Plex Discord] Could not find previous button, trying seek approach');
          // Fallback: seek backward 30 seconds if button not found
          const video = getPlayer();
          if (video) {
            video.currentTime = Math.max(0, video.currentTime - 30);
            console.log('[Plex Discord] Seeked backward 30 seconds');
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

      switch (cmd.action) {
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

setTimeout(() => {
  browser.runtime.sendMessage({type: 'status', status: 'content_ready'}).catch(() => {});
}, 500);
