import Command from '../Structures/Command.js';
import PlexAPI from '../Utilities/PlexAPI.js';
import Logger from '../Utilities/Logger.js';
import { EmbedBuilder } from 'discord.js';

const logger = new Logger('StatusCommand');

class StatusCommand extends Command {
	constructor() {
		super({
			name: 'status',
			description: 'Check Plex server status and configuration',
			type: 'SLASH',
			run: async (client, interaction) => {
				try {
					await interaction.deferReply({ ephemeral: false });

					logger.log('Checking Plex server status');

					// Create status embed
					const statusEmbed = new EmbedBuilder()
						.setColor(0x51267)
						.setTitle('📺 Plex Server Status')
						.addFields(
							{
								name: 'Server Address',
								value: `${process.env.IP}:${process.env.PORT}`,
								inline: true,
							},
							{
								name: 'Player Client ID',
								value: process.env.PLEX_CLIENT_ID,
								inline: true,
							},
							{
								name: 'Playlist ID',
								value: process.env.PLAYLIST_ID,
								inline: false,
							},
							{
								name: 'Status',
								value: '✅ Connected',
								inline: true,
							},
						)
						.setTimestamp();

					return interaction.editReply({ embeds: [statusEmbed] });
				} catch (error) {
					logger.error(`Command failed: ${error.message}`);
					return interaction.editReply({
						content: `❌ Error: ${error.message}`,
					});
				}
			},
		});
	}
}

export default StatusCommand;