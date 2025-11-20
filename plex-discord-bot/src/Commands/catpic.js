import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('CatPicCommand');

/**
 * Cat Pic Command - Fetches a random cat image from TheCatAPI
 */
class CatPicCommand extends Command {
	constructor() {
		super({
			name: 'catpic',
			description: 'Get a random cat picture',
			type: 'SLASH',
			run: async (_, interaction) => {
				try {
					await interaction.deferReply();

					const response = await fetch(
						'https://api.thecatapi.com/v1/images/search',
						{
							headers: {
								'x-api-key': process.env.CAT_API_KEY || '',
							},
						}
					);

					if (!response.ok) {
						throw new Error(`API returned status ${response.status}`);
					}

					const data = await response.json();
					const catImage = data[0];

					const embed = new EmbedBuilder()
						.setColor(0xFF8C00)
						.setTitle('🐱 Random Cat')
						.setImage(catImage.url)
						.setFooter({ text: 'TheCatAPI' })
						.setTimestamp();

					return await interaction.editReply({ embeds: [embed] });
				} catch (error) {
					logger.error(`Failed to fetch cat image: ${error.message}`);
					return await interaction.editReply({
						content: `❌ Failed to fetch a cat image: ${error.message}`,
					});
				}
			},
		});
	}
}

export default CatPicCommand;
