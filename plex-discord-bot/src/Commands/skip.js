import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import { getWebSocketClient } from '../Utilities/WebSocketClient.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('SkipCommand');

class SkipCommand extends Command {
	constructor() {
		super({
			name: 'skip',
			description: '⏭️ Skip to next Plex media via Firefox extension',
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
										'• Navigate to your Plex server (http://192.168.50.80:32400/web)\n' +
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
										'• Navigate to your Plex server (http://192.168.50.80:32400/web)\n' +
										'• Keep Firefox window open'
									)
									.setFooter({ text: 'WebSocket connection required' })
									.setTimestamp(),
							],
						});
					}

					// Send skip command
					logger.log('Sending skip command to Firefox');
					await wsClient.sendCommand({ action: 'next' });

					return interaction.editReply({
						embeds: [
							new EmbedBuilder()
								.setColor(0x00CCFF)
								.setTitle('⏭️ Skipped')
								.setDescription('Skipped to next media in your Plex playlist via Discord')
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

export default SkipCommand;
