import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import moment from 'moment';

/**
 * Founded Command - Shows when the Discord server was founded
 */
class FoundedCommand extends Command {
	constructor() {
		// Calculate the time elapsed since founding date
		const foundedDate = moment([2006, 8, 1]); // August 1st, 2006 (month is 0-indexed in moment constructor)
		const timeElapsed = foundedDate.toNow(true);
		const formattedDate = foundedDate.format('MMMM Do, YYYY');

		super({
			name: 'founded',
			description: 'Show when the Discord server was founded',
			type: 'SLASH',
			run: async (_, interaction) => {
				const embed = new EmbedBuilder()
					.setColor(0x51267)
					.setTitle('🏛️ Server Founding Information')
					.setDescription(
						`This server has existed for **${timeElapsed}**.\n\n` +
						`**Founded:** ${formattedDate}`
					)
					.setThumbnail('https://i.imgur.com/G61IDq3.gif')
					.setFooter({
						text: 'Aim2Win Discord Server',
						iconURL: 'https://i.imgur.com/aBEncq6.png',
					})
					.setTimestamp();

				return await interaction.reply({ embeds: [embed] });
			},
		});
	}
}

export default FoundedCommand;
