import axios from 'axios';

/**
 * Plex API client for interacting with Plex server
 */
class PlexAPI {
	constructor() {
		this.serverURL = `http://${process.env.IP}:${process.env.PORT}`;
		this.playerURL = `http://${process.env.IP}:32500`; // Plex player control port
		// Use public domain for external bot access, or fall back to internal localhost if running inside container
		this.proxyURL = process.env.PLEX_API_PROXY || `https://discord.f00d4tehg0dz.me/plex-api`; // HTTP proxy for search
		this.token = process.env.PLEX_TOKEN;
		this.clientId = process.env.PLEX_CLIENT_ID;
		this.machineIdent = process.env.MACHINE_IDENT;

		// Server client (for search, library, playlists)
		this.serverClient = axios.create({
			baseURL: this.serverURL,
			headers: {
				'X-Plex-Token': this.token,
				'Accept': 'application/json',
			},
			timeout: 60000, // Increased to 60s for slow Plex searches
		});

		// Player client (for playback control on port 32500)
		this.playerClient = axios.create({
			baseURL: this.playerURL,
			headers: {
				'X-Plex-Token': this.token,
				'Accept': 'application/json',
			},
			timeout: 60000, // Increased to 60s for slow Plex searches
		});

		// Proxy client (for search from external bot)
		this.proxyClient = axios.create({
			baseURL: this.proxyURL,
			headers: {
				'Accept': 'application/json',
			},
			timeout: 65000, // Slightly more than server timeout to allow for network delay
		});
	}

	/**
	 * Search for media in Plex library via HTTP proxy
	 * @param {string} query Search query
	 * @param {number} [retries=2] Number of retry attempts on timeout
	 * @returns {Promise<Object>} Search results
	 */
	async search(query, retries = 2) {
		try {
			if (!query || typeof query !== 'string') {
				throw new Error('Query must be a non-empty string');
			}

			console.log(`[PlexAPI] Searching for: ${query} via proxy: ${this.proxyURL}`);
			const response = await this.proxyClient.get('/search', {
				params: {
					query: query.toLowerCase(),
				},
			});

			if (response.data.error) {
				throw new Error(response.data.error);
			}

			console.log(`[PlexAPI] Search found ${response.data.Metadata?.length || 0} results`);
			return response.data;
		} catch (error) {
			console.error(`[PlexAPI] Search error:`, error.response?.status, error.message);

			// Retry on timeout if attempts remain
			if (retries > 0 && (error.code === 'ECONNABORTED' || error.message.includes('timeout'))) {
				console.log(`[PlexAPI] Search timeout detected, retrying... (${retries} attempts remaining)`);
				// Wait 1 second before retrying
				await new Promise(resolve => setTimeout(resolve, 1000));
				return this.search(query, retries - 1);
			}

			throw new Error(`Search failed: ${error.message}`);
		}
	}

	/**
	 * Create a play queue via HTTP proxy
	 * @param {string} [key] Media key to queue
	 * @param {string} [contentType] Type of content (show, movie, episode)
	 * @returns {Promise<string>} Play queue ID
	 */
	async createPlayQueue(key = null, contentType = 'movie') {
		try {
			// Create play queue with just the key - don't use playlistID as it may not be accessible
			// This creates a simple queue for the given media key
			const params = {
				type: 'video',
				shuffle: 1,
				continuous: 1,
			};

			if (key) {
				params.key = key;
			}

			console.log(`[PlexAPI] Creating play queue with content type: ${contentType}`);
			console.log(`[PlexAPI] Creating play queue with params:`, JSON.stringify(params, null, 2));
			console.log(`[PlexAPI] Using proxy for play queue: ${this.proxyURL}`);

			// Use the proxy client to create play queue
			const response = await this.proxyClient.get('/playQueues', {
				params,
			});

			console.log(`[PlexAPI] Play queue response status: ${response.status}`);
			console.log(`[PlexAPI] Play queue response data:`, JSON.stringify(response.data, null, 2));

			const queueId = response.data.playQueueID;

			if (!queueId) {
				if (response.data.warning) {
					console.log(`[PlexAPI] ${response.data.warning}`);
					// Return null to indicate queue creation failed, but don't throw
					return null;
				}
				throw new Error('Play queue ID not found in response');
			}

			console.log(`[PlexAPI] Play queue created with ID: ${queueId}`);
			return queueId;
		} catch (error) {
			console.error(`[PlexAPI] Play queue creation error:`, error.response?.status, error.message);
			if (error.response?.data) {
				console.error(`[PlexAPI] Response data:`, JSON.stringify(error.response.data, null, 2));
			}
			console.error(`[PlexAPI] Full error:`, error);
			throw new Error(`Failed to create play queue: ${error.message}`);
		}
	}

	/**
	 * Control playback on a remote Plex player
	 * @param {string} command Playback command (playMedia, skipNext, play, pause, stop)
	 * @param {Object} [params={}] Additional parameters
	 * @returns {Promise<void>}
	 * @throws {Error} If player doesn't support remote control or isn't running
	 */
	async playback(command, params = {}) {
		try {
			if (!command || typeof command !== 'string') {
				throw new Error('Command must be a non-empty string');
			}

			const playbackParams = {
				commandID: 0,
				'X-Plex-Target-Client-Identifier': this.clientId,
				...params,
			};

			console.log(`[PlexAPI] Playback command: ${command}`);
			console.log(`[PlexAPI] Params:`, JSON.stringify(playbackParams, null, 2));
			console.log(`[PlexAPI] Target Client ID: ${this.clientId}`);

			// Try to send via WebSocket first (for Firefox extension)
			// Retry logic for when WebSocket isn't ready yet
			let wsAttempts = 0;
			const maxWsAttempts = 3;
			let wsSuccess = false;

			while (wsAttempts < maxWsAttempts && !wsSuccess) {
				try {
					const { getWebSocketClient } = await import('./WebSocketClient.js');
					const wsClient = await getWebSocketClient();

					if (wsClient.isReady()) {
						console.log(`[PlexAPI] Sending playback command via WebSocket to Firefox extension`);
						console.log(`[PlexAPI] WebSocket client is ready, sending ${command} command`);
						const wsCommand = {
							action: command,
							params: playbackParams,
						};
						console.log(`[PlexAPI] WebSocket command object:`, JSON.stringify(wsCommand, null, 2));
						await wsClient.sendCommand(wsCommand);
						console.log(`[PlexAPI] Playback command sent successfully via WebSocket`);
						wsSuccess = true;
						return;
					} else {
						wsAttempts++;
						console.log(`[PlexAPI] WebSocket not ready (attempt ${wsAttempts}/${maxWsAttempts}): readyState=${wsClient.ws?.readyState}`);

						if (wsAttempts < maxWsAttempts) {
							// Wait 500ms before retrying
							await new Promise(resolve => setTimeout(resolve, 500));
						}
					}
				} catch (wsError) {
					wsAttempts++;
					console.error(`[PlexAPI] WebSocket error on attempt ${wsAttempts}: ${wsError.message}`);

					if (wsAttempts < maxWsAttempts) {
						// Wait 500ms before retrying
						await new Promise(resolve => setTimeout(resolve, 500));
					}
				}
			}

			if (!wsSuccess) {
				console.log(`[PlexAPI] WebSocket unavailable after ${maxWsAttempts} attempts, attempting fallback to direct player`);
			}

			// Fallback: Try direct player port connection
			const url = `${this.playerURL}/player/playback/${command}`;
			console.log(`[PlexAPI] Attempting direct player connection to port 32500: ${command}`);
			console.log(`[PlexAPI] URL: ${url}`);

			const response = await this.playerClient.get(`/player/playback/${command}`, {
				params: playbackParams,
			});

			console.log(`[PlexAPI] Playback response status: ${response.status}`);
		} catch (error) {
			const status = error.response?.status;
			const message = error.message;

			// Provide helpful error messages based on the error
			if (status === 404) {
				throw new Error(
					'Player not found or does not support remote control. ' +
					'Plex web browsers (Firefox, Chrome) do not support remote control. ' +
					'Please ensure you have a compatible Plex player installed (Media Player, Smart TV, etc).'
				);
			} else if (status === 401) {
				throw new Error('Authentication failed. Check your PLEX_TOKEN in .env');
			} else if (error.code === 'ECONNREFUSED') {
				throw new Error(
					'Could not connect to player on port 32500. ' +
					'Make sure a compatible Plex player is running and connected to the network.'
				);
			}

			console.error(`[PlexAPI] Playback error:`, status, error.response?.statusText);
			console.error(`[PlexAPI] Error message:`, message);
			if (error.response?.data) {
				console.error(`[PlexAPI] Response data:`, error.response.data);
			}
			throw new Error(`Playback command failed: ${message}`);
		}
	}

	/**
	 * Play a specific media item
	 * @param {string} key Media key
	 * @returns {Promise<void>}
	 */
	async playMedia(key) {
		try {
			if (!key || typeof key !== 'string') {
				throw new Error('Key must be a non-empty string');
			}

			// Try to create a play queue, but don't fail if it doesn't work
			// (some tokens may not have permission to create queues)
			let containerKey = null;
			try {
				const pqid = await this.createPlayQueue(key);
				if (pqid) {
					containerKey = `/playQueues/${pqid}?window=100&own=1`;
					console.log(`[PlexAPI] Using play queue: ${containerKey}`);
				} else {
					console.log(`[PlexAPI] Play queue creation returned null, will attempt direct playback`);
				}
			} catch (error) {
				console.log(`[PlexAPI] Play queue creation failed, will attempt direct playback: ${error.message}`);
			}

			// Fetch the actual Plex server ID from the identity endpoint
			// The machineIdent is the CLIENT ID, not the SERVER ID
			let serverId = this.machineIdent; // Fallback to client ID
			try {
				const idResponse = await this.proxyClient.get('/identity');
				if (idResponse.data && idResponse.data.machineIdentifier) {
					serverId = idResponse.data.machineIdentifier;
					console.log(`[PlexAPI] Got server ID from identity endpoint: ${serverId}`);
				}
			} catch (e) {
				console.warn(`[PlexAPI] Could not fetch server ID: ${e.message}`);
			}

			const params = {
				providerIdentifier: 'com.plexapp.plugins.library',
				key,
				offset: 0,
				machineIdentifier: this.machineIdent,
				serverId: serverId,  // Add the actual server ID for Plex web navigation
				address: process.env.IP,
				port: process.env.PORT,
				token: this.token,
			};

			// Only add containerKey if we successfully created a play queue
			if (containerKey) {
				params.containerKey = containerKey;
			}

			await this.playback('playMedia', params);
		} catch (error) {
			throw new Error(`Failed to play media: ${error.message}`);
		}
	}

	/**
	 * Skip to next media
	 * @returns {Promise<void>}
	 */
	async skipNext() {
		const params = {
			machineIdentifier: this.machineIdent,
			address: process.env.IP,
			port: process.env.PORT,
		};
		return this.playback('skipNext', params);
	}

	/**
	 * Resume playback
	 * @returns {Promise<void>}
	 */
	async play() {
		const params = {
			machineIdentifier: this.machineIdent,
			address: process.env.IP,
			port: process.env.PORT,
		};
		return this.playback('play', params);
	}

	/**
	 * Pause playback
	 * @returns {Promise<void>}
	 */
	async pause() {
		const params = {
			machineIdentifier: this.machineIdent,
			address: process.env.IP,
			port: process.env.PORT,
		};
		return this.playback('pause', params);
	}

	/**
	 * Stop playback
	 * @returns {Promise<void>}
	 */
	async stop() {
		const params = {
			machineIdentifier: this.machineIdent,
			address: process.env.IP,
			port: process.env.PORT,
		};
		return this.playback('stop', params);
	}
}

export default new PlexAPI();
