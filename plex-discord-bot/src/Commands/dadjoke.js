import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';
import Logger from '../Utilities/Logger.js';

const logger = new Logger('DadJokeCommand');

/**
 * Dad Joke Command - Fetches a random dad joke from icanhazdadjoke.com
 */
class DadJokeCommand extends Command {
	constructor() {
		super({
			name: 'dadjoke',
			description: 'Get a random dad joke',
			type: 'SLASH',
			run: async (_, interaction) => {
				try {
					await interaction.deferReply();

					const response = await fetch('https://icanhazdadjoke.com/api');

					if (!response.ok) {
						throw new Error(`API returned status ${response.status}`);
					}

					const data = await response.json();

					const embed = new EmbedBuilder()
						.setColor(0xFFA500)
						.setTitle('😄 Dad Joke')
						.setDescription(data.joke)
						.setFooter({ text: 'icanhazdadjoke.com' })
						.setTimestamp();

					return await interaction.editReply({ embeds: [embed] });
				} catch (error) {
					logger.error(`Failed to fetch dad joke: ${error.message}`);
					return await interaction.editReply({
						content: `❌ Failed to fetch a dad joke: ${error.message}`,
					});
				}
			},
		});
	}
}

export default DadJokeCommand;
