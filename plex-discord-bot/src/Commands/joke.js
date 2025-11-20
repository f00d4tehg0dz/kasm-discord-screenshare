import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('JokeCommand');

/**
 * Joke Command - Fetches a random joke from API Ninjas
 */
class JokeCommand extends Command {
	constructor() {
		super({
			name: 'joke',
			description: 'Get a random joke',
			type: 'SLASH',
			run: async (_, interaction) => {
				try {
					await interaction.deferReply();

					const response = await fetch('https://api.api-ninjas.com/v1/jokes', {
						headers: {
							'X-Api-Key': process.env.API_NINJAS_KEY || 'demo',
						},
					});

					if (!response.ok) {
						throw new Error(`API returned status ${response.status}`);
					}

					const data = await response.json();
					const joke = data[0];

					const embed = new EmbedBuilder()
						.setColor(0x6366F1)
						.setTitle('😂 Joke')
						.setDescription(joke.joke)
						.setFooter({ text: 'API Ninjas' })
						.setTimestamp();

					return await interaction.editReply({ embeds: [embed] });
				} catch (error) {
					logger.error(`Failed to fetch joke: ${error.message}`);
					return await interaction.editReply({
						content: `❌ Failed to fetch a joke: ${error.message}`,
					});
				}
			},
		});
	}
}

export default JokeCommand;
