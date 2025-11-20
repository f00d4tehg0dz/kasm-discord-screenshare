import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('DogPicCommand');

/**
 * Dog Pic Command - Fetches a random dog image from Dog.ceo API
 */
class DogPicCommand extends Command {
	constructor() {
		super({
			name: 'dogpic',
			description: 'Get a random dog picture',
			type: 'SLASH',
			run: async (_, interaction) => {
				try {
					await interaction.deferReply();

					const response = await fetch('https://dog.ceo/api/breeds/image/random');

					if (!response.ok) {
						throw new Error(`API returned status ${response.status}`);
					}

					const data = await response.json();

					if (data.status !== 'success') {
						throw new Error('Failed to fetch dog image from API');
					}

					const embed = new EmbedBuilder()
						.setColor(0x8B4513)
						.setTitle('🐕 Random Dog')
						.setImage(data.message)
						.setFooter({ text: 'Dog.ceo API' })
						.setTimestamp();

					return await interaction.editReply({ embeds: [embed] });
				} catch (error) {
					logger.error(`Failed to fetch dog image: ${error.message}`);
					return await interaction.editReply({
						content: `❌ Failed to fetch a dog image: ${error.message}`,
					});
				}
			},
		});
	}
}

export default DogPicCommand;
