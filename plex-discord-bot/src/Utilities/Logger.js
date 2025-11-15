/**
 * Logger utility for consistent logging
 */
class Logger {
	constructor(prefix = 'PlexBot') {
		this.prefix = prefix;
	}

	_formatMessage(level, message) {
		const timestamp = new Date().toISOString();
		return `[${timestamp}] [${this.prefix}] [${level}] ${message}`;
	}

	log(message) {
		console.log(this._formatMessage('LOG', message));
	}

	info(message) {
		console.info(this._formatMessage('INFO', message));
	}

	warn(message) {
		console.warn(this._formatMessage('WARN', message));
	}

	error(message) {
		console.error(this._formatMessage('ERROR', message));
	}

	success(message) {
		console.log(`\x1b[32m${this._formatMessage('SUCCESS', message)}\x1b[0m`);
	}

	debug(message) {
		if (process.env.DEBUG === 'true') {
			console.debug(this._formatMessage('DEBUG', message));
		}
	}
}

export default Logger;