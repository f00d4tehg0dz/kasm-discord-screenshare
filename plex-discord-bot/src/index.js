import 'dotenv/config.js';
import PlexBot from './Structures/Client.js';
import Logger from './Utilities/Logger.js';

const logger = new Logger('Main');

/**
 * Start the bot
 */
async function main() {
	try {
		logger.log('Initializing PlexDiscordBot...');

		// Validate required environment variables
		const requiredEnvVars = [
			'TOKEN',
			'CLIENT_ID',
			'IP',
			'PORT',
			'PLEX_TOKEN',
			'PLEX_CLIENT_ID',
			'MACHINE_IDENT',
		];

		const missingEnvVars = requiredEnvVars.filter(
			envVar => !process.env[envVar]
		);

		if (missingEnvVars.length > 0) {
			logger.error(
				`Missing required environment variables: ${missingEnvVars.join(', ')}`
			);
			process.exit(1);
		}

		logger.success('All required environment variables found');

		// Create and start the bot
		const bot = new PlexBot();
		await bot.start();

		logger.success('Bot started successfully');
	} catch (error) {
		logger.error(`Fatal error: ${error.message}`);
		process.exit(1);
	}
}

// Handle uncaught exceptions
process.on('uncaughtException', error => {
	logger.error(`Uncaught Exception: ${error.message}`);
	process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', error => {
	logger.error(`Unhandled Rejection: ${error.message}`);
	process.exit(1);
});

main();