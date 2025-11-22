import Event from '../Structures/Event.js';
import Logger from '../Utilities/Logger.js';
import PlexAPI from '../Utilities/PlexAPI.js';
import { getWebSocketClient } from '../Utilities/WebSocketClient.js';

const logger = new Logger('InteractionEvent');

class InteractionCreateEvent extends Event {
	constructor() {
		super({
			event: 'interactionCreate',
			run: async (client, interaction) => {
				// Handle slash commands
				if (interaction.isChatInputCommand()) {
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
				}

				// Handle select menu interactions
				if (interaction.isStringSelectMenu()) {
					if (interaction.customId === 'suggest_select') {
						try {
							await interaction.deferReply({ ephemeral: false });

							const selectedIndex = parseInt(interaction.values[0].split('_')[1]);
							const results = global.suggestResults?.get(interaction.user.id);

							if (!results || !results[selectedIndex]) {
								return await interaction.editReply({
									content: '❌ Suggestion not found. Please try the command again.',
								});
							}

							const selected = results[selectedIndex];

							logger.log(`User selected: ${selected.plexTitle || selected.title}`);

							// If not in library, inform user
							if (!selected.plexKey) {
								return await interaction.editReply({
									content: `⚠️ **${selected.title}** is not available in your Plex library. Please add it to watch it!`,
								});
							}

							// Queue the selected media
							await PlexAPI.playMedia(selected.plexKey);

							let responseText = `▶️ Queued **${selected.plexTitle}** for playback!`;

							// Try to send play and fullscreen commands
							try {
								const wsClient = await getWebSocketClient();
								if (wsClient.isReady()) {
									await wsClient.sendCommand({ action: 'play' });
									await wsClient.sendCommand({ action: 'fullscreen' });
									responseText += '\n\n✅ Playing in fullscreen via Firefox extension!';
								} else {
									responseText += '\n\n⚠️ Firefox extension not connected. Use `/resume` to start playback and press F for fullscreen.';
								}
							} catch (wsError) {
								logger.warn(`WebSocket command failed: ${wsError.message}`);
								responseText += '\n\n⚠️ Content queued but automatic playback unavailable.';
							}

							return await interaction.editReply({
								content: responseText,
								components: [],
							});
						} catch (error) {
							logger.error(`Error handling select menu: ${error.message}`);
							return await interaction.editReply({
								content: `❌ Error: ${error.message}`,
							});
						}
					}
				}
			},
		});
	}
}

export default InteractionCreateEvent;