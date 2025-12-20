import { WebSocket } from 'ws';
import https from 'https';
import Logger from './Logger.js';

const logger = new Logger('WebSocketClient');

class WebSocketClient {
	constructor(url) {
		// Allow URL to be passed, use environment variable, or use default
		if (!url) {
			url = process.env.DISCORD_BOT_WS_URL || 'wss://discord.f00d4tehg0dz.me/discord';
		}
		this.url = url;
		this.ws = null;
		this.isConnected = false;
		this.reconnectAttempts = 0;
		this.maxReconnectAttempts = parseInt(process.env.MAX_RECONNECT_ATTEMPTS || '5', 10);
		this.reconnectDelay = parseInt(process.env.RECONNECT_DELAY || '3000', 10);
		this.pendingRequests = new Map();
		this.requestId = 0;
		
		// Cloudflare Zero Trust Service Token credentials
		this.cfAccessClientId = process.env.CF_ACCESS_CLIENT_ID || '';
		this.cfAccessClientSecret = process.env.CF_ACCESS_CLIENT_SECRET || '';
	}

	/**
	 * Connect to the WebSocket server
	 */
	async connect() {
		return new Promise((resolve, reject) => {
			try {
				// Options for WebSocket connection
				const options = {
					headers: {},
				};

				// Add Cloudflare Access Service Token headers if configured
				if (this.cfAccessClientId && this.cfAccessClientSecret) {
					options.headers['CF-Access-Client-Id'] = this.cfAccessClientId;
					options.headers['CF-Access-Client-Secret'] = this.cfAccessClientSecret;
					logger.log('Using Cloudflare Access Service Token for authentication');
				}

				// For WSS connections, create an HTTPS agent with certificate bypass
				if (this.url.startsWith('wss://')) {
					const url = new URL(this.url);
					const httpsAgent = new https.Agent({
						rejectUnauthorized: false,
						keepAlive: true,
						keepAliveMsecs: 1000,
					});
					options.agent = httpsAgent;
					// Set servername for SNI (Server Name Indication)
					options.servername = url.hostname;
				}

				this.ws = new WebSocket(this.url, undefined, options);

				this.ws.on('open', () => {
					logger.log(`Connected to WebSocket server at ${this.url}`);
					this.isConnected = true;
					this.reconnectAttempts = 0;
					resolve();
				});

				this.ws.on('message', (data) => {
					try {
						const message = JSON.parse(data.toString());
						this._handleMessage(message);
					} catch (err) {
						logger.error(`Failed to parse message: ${err.message}`);
					}
				});

				this.ws.on('error', (error) => {
					logger.error(`WebSocket error: ${error.message}`);
					reject(error);
				});

				this.ws.on('close', () => {
					logger.log('WebSocket connection closed');
					this.isConnected = false;
					this._attemptReconnect();
				});

				// Set a timeout for connection attempt
				setTimeout(() => {
					if (!this.isConnected) {
						reject(new Error('Connection timeout'));
					}
				}, 2000);
			} catch (err) {
				logger.error(`Failed to create WebSocket: ${err.message}`);
				reject(err);
			}
		});
	}

	/**
	 * Send a command to the browser extension
	 * @param {Object} command - Command object with action and optional parameters
	 * @returns {Promise} Response from the browser
	 */
	async sendCommand(command) {
		if (!this.isConnected || !this.ws) {
			throw new Error('WebSocket not connected');
		}

		return new Promise((resolve, reject) => {
			const id = ++this.requestId;
			const timeout = setTimeout(() => {
				this.pendingRequests.delete(id);
				reject(new Error(`Command timeout: ${command.action}`));
			}, 2000);

			this.pendingRequests.set(id, { resolve, reject, timeout });

			try {
				this.ws.send(
					JSON.stringify({
						id,
						...command,
					})
				);
				logger.log(`Sent command: ${command.action}`);
			} catch (err) {
				clearTimeout(timeout);
				this.pendingRequests.delete(id);
				reject(new Error(`Failed to send command: ${err.message}`));
			}
		});
	}

	/**
	 * Handle incoming messages from browser
	 */
	_handleMessage(message) {
		const { id, status, error } = message;

		if (id && this.pendingRequests.has(id)) {
			const { resolve, reject, timeout } = this.pendingRequests.get(id);
			clearTimeout(timeout);
			this.pendingRequests.delete(id);

			if (error) {
				reject(new Error(error));
			} else {
				resolve({ status, ...message });
			}
		}
	}

	/**
	 * Attempt to reconnect after disconnection
	 */
	async _attemptReconnect() {
		if (this.reconnectAttempts < this.maxReconnectAttempts) {
			this.reconnectAttempts++;
			logger.log(
				`Reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${this.reconnectDelay}ms`
			);

			setTimeout(() => {
				this.connect().catch((err) => {
					logger.error(`Reconnection failed: ${err.message}`);
				});
			}, this.reconnectDelay);
		} else {
			logger.error('Max reconnection attempts reached');
		}
	}

	/**
	 * Close the WebSocket connection
	 */
	close() {
		if (this.ws) {
			this.ws.close();
			this.isConnected = false;
		}
	}

	/**
	 * Check if connected
	 */
	isReady() {
		return this.isConnected && this.ws && this.ws.readyState === 1;
	}
}

// Create a singleton instance
let instance = null;

export async function getWebSocketClient() {
	if (!instance) {
		instance = new WebSocketClient();
		try {
			await instance.connect();
		} catch (err) {
			logger.error(`Failed to initialize WebSocket: ${err.message}`);
			instance = null;
			throw err;
		}
	}
	return instance;
}

export default WebSocketClient;