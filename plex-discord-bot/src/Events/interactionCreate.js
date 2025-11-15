import Event from '../Structures/Event.js';
import Logger from '../Utilities/Logger.js';
import { hasPermission, getPermissionDeniedMessage } from '../Utilities/permissions.js';

const logger = new Logger('InteractionEvent');

// User IDs with permission bypass
const ALLOWED_USERS = ['XXXXXXXX', 'YYYYYYYY']; // Replace with actual user IDs

class InteractionCreateEvent extends Event {
	constructor() {
		super({
			event: 'interactionCreate',
			run: async (client, interaction) => {
				// Only handle slash commands
				if (!interaction.isChatInputCommand()) return;

				const command = client.commands.get(interaction.commandName);

				if (!command) {
					logger.warn(`Command not found: ${interaction.commandName}`);
					return interaction.reply({
						content: '❌ Command not found.',
						ephemeral: true,
					});
				}

				// Check permissions
				if (!hasPermission(interaction, process.env.ROLE_ID, ALLOWED_USERS)) {
					logger.warn(`Permission denied for user ${interaction.user.id} on command ${interaction.commandName}`);
					return interaction.reply(getPermissionDeniedMessage());
				}

				try {
					logger.log(`Executing command: ${command.name} by ${interaction.user.tag}`);
					await command.run(client, interaction);
				} catch (error) {
					logger.error(`Error executing command ${command.name}: ${error.message}`);

					const errorMessage = {
						content: '❌ An error occurred while executing this command.',
						ephemeral: true,
					};

					// Reply or follow-up based on interaction state
					if (interaction.replied) {
						return interaction.followUp(errorMessage);
					} else if (interaction.deferred) {
						return interaction.editReply(errorMessage);
					} else {
						return interaction.reply(errorMessage);
					}
				}
			},
		});
	}
}

export default InteractionCreateEvent;