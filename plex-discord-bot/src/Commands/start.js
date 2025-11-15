import Command from '../Structures/Command.js';
import PlexAPI from '../Utilities/PlexAPI.js';
import Logger from '../Utilities/Logger.js';
import { EmbedBuilder } from 'discord.js';

const logger = new Logger('StartCommand');

class StartCommand extends Command {
	constructor() {
		super({
			name: 'start',
			description: 'Create a new shuffled playlist queue from your library',
			type: 'SLASH',
			run: async (client, interaction) => {
				try {
					await interaction.deferReply({ ephemeral: false });

					logger.log('Creating new play queue');
					const queueId = await PlexAPI.createPlayQueue();

					const embed = new EmbedBuilder()
						.setColor(0x51267)
						.setTitle('🎬 New Queue Created')
						.setDescription(`Successfully created a shuffled playlist queue`)
						.addFields(
							{
								name: 'Queue ID',
								value: queueId,
								inline: true,
							},
							{
								name: 'Status',
								value: '✅ Ready to play',
								inline: true,
							},
							{
								name: '📌 Next Steps',
								value:
									'1. Go to your Plex web player in Firefox\n' +
									'2. Refresh the page to load the new queue\n' +
									'3. Click play to start the shuffled playlist\n' +
									'4. Use Firefox controls to pause/seek',
								inline: false,
							}
						)
						.setFooter({ text: 'Tip: Use /play to search for specific movies' })
						.setTimestamp();

					return interaction.editReply({ embeds: [embed] });
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

export default StartCommand;
