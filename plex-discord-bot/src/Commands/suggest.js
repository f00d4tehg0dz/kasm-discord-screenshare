import Command from '../Structures/Command.js';
import { EmbedBuilder, ActionRowBuilder, StringSelectMenuBuilder } from 'discord.js';
import Logger from '../Utilities/Logger.js';
import PlexAPI from '../Utilities/PlexAPI.js';

const logger = new Logger('SuggestCommand');

/**
 * Suggest Command - Uses ChatGPT to suggest movies/shows based on user preferences
 */
class SuggestCommand extends Command {
	constructor() {
		super({
			name: 'suggest',
			description: 'Get ChatGPT suggestions for movies/shows based on your preferences',
			type: 'SLASH',
			slashCommandOptions: [
				{
					name: 'mood',
					description: 'What mood are you in? (e.g., scary, funny, action-packed, romantic)',
					type: 3, // STRING type
					required: true,
				},
				{
					name: 'genre',
					description: 'Preferred genre (e.g., horror, comedy, action, drama, sci-fi)',
					type: 3, // STRING type
					required: false,
				},
			],
			run: async (_, interaction) => {
				try {
					await interaction.deferReply({ ephemeral: false });

					const mood = interaction.options.getString('mood');
					const genre = interaction.options.getString('genre') || 'any genre';

					logger.log(`Getting suggestions for mood: ${mood}, genre: ${genre}`);

					// Send loading message
					await interaction.editReply({
						content: `🤔 ChatGPT is thinking about ${mood} ${genre} recommendations...`,
					});

					// Call ChatGPT API to get suggestions
					const suggestions = await this.getGPTSuggestions(mood, genre);

					if (!suggestions || suggestions.length === 0) {
						return await interaction.editReply({
							content: '❌ Failed to get suggestions from ChatGPT. Please try again.',
						});
					}

					// Search Plex for each suggestion
					const results = [];
					for (const suggestion of suggestions.slice(0, 5)) {
						try {
							const searchResults = await PlexAPI.search(suggestion.title);
							if (searchResults?.Metadata && searchResults.Metadata.length > 0) {
								const match = searchResults.Metadata[0];
								results.push({
									title: suggestion.title,
									description: suggestion.description,
									plexKey: match.key,
									plexTitle: match.title,
									year: match.year,
									type: match.type,
									summary: match.summary,
								});
							} else {
								// Add without Plex match
								results.push({
									title: suggestion.title,
									description: suggestion.description,
									plexKey: null,
									plexTitle: null,
									year: suggestion.year,
									type: suggestion.type,
									summary: suggestion.description,
								});
							}
						} catch (err) {
							logger.warn(`Failed to search for ${suggestion.title}: ${err.message}`);
							// Still add the suggestion even if search fails
							results.push({
								title: suggestion.title,
								description: suggestion.description,
								plexKey: null,
								plexTitle: null,
								year: suggestion.year,
								type: suggestion.type,
								summary: suggestion.description,
							});
						}
					}

					// Build embed with suggestions
					const embed = new EmbedBuilder()
						.setColor(0x10B981)
						.setTitle(`🎬 ChatGPT Suggestions`)
						.setDescription(`Based on your mood: **${mood}**${genre !== 'any genre' ? ` and genre: **${genre}**` : ''}`)
						.setFooter({ text: 'Select an option below to play it!' })
						.setTimestamp();

					// Add suggestions to embed
					results.forEach((result, index) => {
						const emoji = result.type === 'show' ? '📺' : '🎬';
						const status = result.plexKey ? '✅ In Library' : '⚠️ Not in Library';

						embed.addFields({
							name: `${index + 1}. ${emoji} ${result.plexTitle || result.title}`,
							value: `${result.description}\n\n*${status}*`,
							inline: false,
						});
					});

					// Create select menu for available options
					const selectOptions = results
						.map((result, index) => ({
							label: result.plexTitle || result.title,
							value: `suggest_${index}`,
							description: result.description.substring(0, 100),
							emoji: result.type === 'show' ? '📺' : '🎬',
						}));

					const selectMenu = new StringSelectMenuBuilder()
						.setCustomId('suggest_select')
						.setPlaceholder('Select a title to play')
						.addOptions(selectOptions);

					const actionRow = new ActionRowBuilder().addComponents(selectMenu);

					// Store results in a temporary map for the interaction handler
					// Note: In production, you'd want to use a database or cache for this
					global.suggestResults = global.suggestResults || new Map();
					global.suggestResults.set(interaction.user.id, results);

					// Set expiry for results (5 minutes)
					setTimeout(() => {
						global.suggestResults.delete(interaction.user.id);
					}, 300000);

					return await interaction.editReply({
						embeds: [embed],
						components: [actionRow],
					});
				} catch (error) {
					logger.error(`Command failed: ${error.message}`);
					return await interaction.editReply({
						content: `❌ Error: ${error.message}`,
					});
				}
			},
		});
	}

	/**
	 * Get suggestions from ChatGPT API
	 * @param {string} mood - User's mood/preference
	 * @param {string} genre - Preferred genre
	 * @returns {Array} Array of suggestion objects
	 */
	async getGPTSuggestions(mood, genre) {
		try {
			const apiKey = process.env.OPENAI_API_KEY;

			if (!apiKey) {
				logger.warn('OPENAI_API_KEY not set, using fallback suggestions');
				return this.getFallbackSuggestions(mood, genre);
			}

			const response = await fetch('https://api.openai.com/v1/chat/completions', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${apiKey}`,
				},
				body: JSON.stringify({
					model: 'gpt-3.5-turbo',
					messages: [
						{
							role: 'system',
							content:
								'You are a movie and TV show recommendation assistant. Suggest exactly 5 movies or TV shows based on the user\'s mood and genre preferences. Return suggestions as a JSON array with this format: [{"title": "Movie/Show Title", "description": "One sentence description", "year": 2023, "type": "movie" or "show"}, ...]',
						},
						{
							role: 'user',
							content: `I\'m in the mood for something ${mood} and I like ${genre}. Please suggest 5 titles.`,
						},
					],
					temperature: 0.8,
					max_tokens: 500,
				}),
			});

			if (!response.ok) {
				throw new Error(`ChatGPT API error: ${response.statusText}`);
			}

			const data = await response.json();
			const content = data.choices[0]?.message?.content;

			if (!content) {
				throw new Error('No response from ChatGPT');
			}

			// Extract JSON from response
			const jsonMatch = content.match(/\[[\s\S]*\]/);
			if (!jsonMatch) {
				logger.warn('Could not parse ChatGPT response as JSON');
				return this.getFallbackSuggestions(mood, genre);
			}

			const suggestions = JSON.parse(jsonMatch[0]);
			logger.log(`Got ${suggestions.length} suggestions from ChatGPT`);
			return suggestions;
		} catch (error) {
			logger.error(`ChatGPT API error: ${error.message}`);
			return this.getFallbackSuggestions(mood, genre);
		}
	}

	/**
	 * Fallback suggestions if ChatGPT fails
	 * @param {string} mood - User's mood
	 * @param {string} genre - Preferred genre
	 * @returns {Array} Array of fallback suggestions
	 */
	getFallbackSuggestions(mood, genre) {
		const allSuggestions = {
			scary: [
				{ title: 'The Shining', description: 'Psychological horror masterpiece', year: 1980, type: 'movie' },
				{ title: 'Hereditary', description: 'Modern horror about a cursed family', year: 2018, type: 'movie' },
				{ title: 'The Conjuring', description: 'Supernatural horror thriller', year: 2013, type: 'movie' },
				{ title: 'Insidious', description: 'Creepy haunted house story', year: 2010, type: 'movie' },
				{ title: 'Stranger Things', description: 'Sci-fi horror series', year: 2016, type: 'show' },
			],
			funny: [
				{ title: 'The Grand Budapest Hotel', description: 'Whimsical comedy-drama', year: 2014, type: 'movie' },
				{ title: 'Superbad', description: 'Hilarious coming-of-age comedy', year: 2007, type: 'movie' },
				{ title: 'The Office', description: 'Mockumentary comedy series', year: 2005, type: 'show' },
				{ title: 'Parks and Recreation', description: 'Feel-good comedy series', year: 2009, type: 'show' },
				{ title: 'Step Brothers', description: 'Comedy about feuding siblings', year: 2008, type: 'movie' },
			],
			action: [
				{ title: 'John Wick', description: 'Stylish action thriller', year: 2014, type: 'movie' },
				{ title: 'Mad Max: Fury Road', description: 'High-octane action spectacle', year: 2015, type: 'movie' },
				{ title: 'The Dark Knight', description: 'Epic superhero action', year: 2008, type: 'movie' },
				{ title: 'Mission: Impossible - Fallout', description: 'Intense spy action', year: 2018, type: 'movie' },
				{ title: 'Breaking Bad', description: 'Intense crime drama series', year: 2008, type: 'show' },
			],
			romantic: [
				{ title: 'La La Land', description: 'Musical love story', year: 2016, type: 'movie' },
				{ title: 'The Notebook', description: 'Emotional romance', year: 2004, type: 'movie' },
				{ title: 'Eternal Sunshine of the Spotless Mind', description: 'Unique romance story', year: 2004, type: 'movie' },
				{ title: 'Pride and Prejudice', description: 'Classic romance adaptation', year: 2005, type: 'movie' },
				{ title: 'You', description: 'Dark romance thriller series', year: 2018, type: 'show' },
			],
		};

		// Get suggestions for the mood or return random
		const moodLower = mood.toLowerCase();
		let suggestions = allSuggestions[moodLower];

		if (!suggestions) {
			// Return a mix of popular titles if mood not found
			suggestions = [
				{ title: 'Inception', description: 'Mind-bending sci-fi thriller', year: 2010, type: 'movie' },
				{ title: 'The Crown', description: 'Historical drama series', year: 2016, type: 'show' },
				{ title: 'Interstellar', description: 'Epic space exploration', year: 2014, type: 'movie' },
				{ title: 'Parasite', description: 'Award-winning thriller', year: 2019, type: 'movie' },
				{ title: 'Stranger Things', description: 'Sci-fi horror series', year: 2016, type: 'show' },
			];
		}

		return suggestions;
	}
}

export default SuggestCommand;
