import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import { getWebSocketClient } from '../Utilities/WebSocketClient.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('PauseCommand');

class PauseCommand extends Command {
	constructor() {
		super({
			name: 'pause',
			description: '⏸️ Pause Plex playback via Firefox extension',
			type: 'SLASH',
			run: async (_, interaction) => {
				try {
					await interaction.deferReply({ ephemeral: false });

					// Get WebSocket client with error handling
					let wsClient;
					try {
						wsClient = await getWebSocketClient();
					} catch (wsError) {
						logger.error(`WebSocket connection failed: ${wsError.message}`);
						return interaction.editReply({
							embeds: [
								new EmbedBuilder()
									.setColor(0xFF6B6B)
									.setTitle('❌ Connection Failed')
									.setDescription(
										'Cannot connect to Plex browser extension.\n\n' +
										'**Requirements:**\n' +
										'• Firefox with Plex Discord Control extension installed\n' +
										'• Navigate to your Plex server (http://192.168.50.63:32400/web)\n' +
										'• Keep Firefox window open'
									)
									.setFooter({ text: 'WebSocket connection required' })
									.setTimestamp(),
							],
						});
					}

					if (!wsClient || !wsClient.isReady()) {
						return interaction.editReply({
							embeds: [
								new EmbedBuilder()
									.setColor(0xFF6B6B)
									.setTitle('❌ Connection Failed')
									.setDescription(
										'WebSocket connection not ready.\n\n' +
										'**Requirements:**\n' +
										'• Firefox with Plex Discord Control extension installed\n' +
										'• Navigate to your Plex server (http://192.168.50.63:32400/web)\n' +
										'• Keep Firefox window open'
									)
									.setFooter({ text: 'WebSocket connection required' })
									.setTimestamp(),
							],
						});
					}

					// Send pause command
					logger.log('Sending pause command to Firefox');
					await wsClient.sendCommand({ action: 'pause' });

					return interaction.editReply({
						embeds: [
							new EmbedBuilder()
								.setColor(0xFFA500)
								.setTitle('⏸️ Playback Paused')
								.setDescription('Plex playback has been paused via Discord')
								.setFooter({ text: 'Firefox extension control' })
								.setTimestamp(),
						],
					});
				} catch (error) {
					logger.error(`Command failed: ${error.message}`);
					try {
						return interaction.editReply({
							embeds: [
								new EmbedBuilder()
									.setColor(0xFF6B6B)
									.setTitle('❌ Command Failed')
									.setDescription(`**Error:** ${error.message}\n\n**Troubleshooting:**\nMake sure Firefox is open with Plex loaded`)
									.setTimestamp(),
							],
						});
					} catch (replyError) {
						logger.error(`Failed to send error reply: ${replyError.message}`);
					}
				}
			},
		});
	}
}

export default PauseCommand;
