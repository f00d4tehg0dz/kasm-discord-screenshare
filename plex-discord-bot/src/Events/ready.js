import Event from '../Structures/Event.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('ReadyEvent');

class ReadyEvent extends Event {
	constructor() {
		super({
			event: 'ready',
			run: async (client) => {
				logger.success(`Bot logged in as ${client.user.tag}`);
				logger.info(`Loaded ${client.commands.size} commands`);
				logger.info(`Loaded ${client.events.size} events`);

				// Register slash commands
				await client.registerSlashCommands();
			},
			once: true,
		});
	}
}

export default ReadyEvent;