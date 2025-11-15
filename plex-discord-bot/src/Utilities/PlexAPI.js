import axios from 'axios';

/**
 * Plex API client for interacting with Plex server
 */
class PlexAPI {
	constructor() {
		this.serverURL = `http://${process.env.IP}:${process.env.PORT}`;
		this.playerURL = `http://${process.env.IP}:32500`; // Plex player control port
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
			timeout: 5000,
		});

		// Player client (for playback control on port 32500)
		this.playerClient = axios.create({
			baseURL: this.playerURL,
			headers: {
				'X-Plex-Token': this.token,
				'Accept': 'application/json',
			},
			timeout: 5000,
		});
	}

	/**
	 * Search for media in Plex library
	 * @param {string} query Search query
	 * @returns {Promise<Object>} Search results
	 */
	async search(query) {
		try {
			if (!query || typeof query !== 'string') {
				throw new Error('Query must be a non-empty string');
			}

			console.log(`[PlexAPI] Searching for: ${query}`);
			const response = await this.serverClient.get('/search', {
				params: {
					query: query.toLowerCase(),
				},
			});

			console.log(`[PlexAPI] Search found ${response.data.MediaContainer?.Metadata?.length || 0} results`);
			return response.data.MediaContainer;
		} catch (error) {
			console.error(`[PlexAPI] Search error:`, error.response?.status, error.message);
			throw new Error(`Search failed: ${error.message}`);
		}
	}

	/**
	 * Create a play queue
	 * @param {string} [key] Media key to queue
	 * @returns {Promise<string>} Play queue ID
	 */
	async createPlayQueue(key = null) {
		try {
			const params = {
				playlistID: process.env.PLAYLIST_ID,
				type: 'video',
				shuffle: 1,
				continuous: 1,
			};

			if (key) {
				params.key = key;
			}

			console.log(`[PlexAPI] Creating play queue with params:`, JSON.stringify(params, null, 2));
			const response = await this.serverClient.post('/playQueues', null, {
				params,
			});

			const queueId = response.data.MediaContainer.playQueueID;
			console.log(`[PlexAPI] Play queue created with ID: ${queueId}`);
			return queueId;
		} catch (error) {
			console.error(`[PlexAPI] Play queue creation error:`, error.response?.status, error.message);
			if (error.response?.data) {
				console.error(`[PlexAPI] Response data:`, error.response.data);
			}
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

			const url = `${this.playerURL}/player/playback/${command}`;
			console.log(`[PlexAPI] Playback request to port 32500: ${command}`);
			console.log(`[PlexAPI] URL: ${url}`);
			console.log(`[PlexAPI] Params:`, JSON.stringify(playbackParams, null, 2));
			console.log(`[PlexAPI] Target Client ID: ${this.clientId}`);

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

			const pqid = await this.createPlayQueue(key);

			const params = {
				providerIdentifier: 'com.plexapp.plugins.library',
				key,
				offset: 0,
				machineIdentifier: this.machineIdent,
				address: process.env.IP,
				port: process.env.PORT,
				containerKey: `/playQueues/${pqid}?window=100&own=1`,
				token: this.token,
			};

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
