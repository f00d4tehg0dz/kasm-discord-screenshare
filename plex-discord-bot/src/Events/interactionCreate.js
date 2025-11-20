import Event from '../Structures/Event.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('InteractionEvent');

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

				// Allow any registered server member to use commands
				// No additional permission checks needed - if they can execute a slash command, they're authorized
				logger.log(`User ${interaction.user.tag} (${interaction.user.id}) is authorized (server member)`);


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