import Command from '../Structures/Command.js';
import PlexAPI from '../Utilities/PlexAPI.js';
import Logger from '../Utilities/Logger.js';
import { EmbedBuilder } from 'discord.js';
import { getWebSocketClient } from '../Utilities/WebSocketClient.js';

const logger = new Logger('PlayCommand');

class PlayCommand extends Command {
	constructor() {
		super({
			name: 'play',
			description: 'Search for movies and queue them to your Plex playlist',
			type: 'SLASH',
			slashCommandOptions: [
				{
					name: 'query',
					description: 'Movie title to search for',
					type: 3, // STRING type
					required: true,
				},
				{
					name: 'limit',
					description: 'Number of results to show (1-10, default: 5)',
					type: 4, // INTEGER type
					required: false,
				},
				{
					name: 'autoplay',
					description: 'Auto-play first result via Firefox extension (default: false)',
					type: 5, // BOOLEAN type
					required: false,
				},
			],
			run: async (_, interaction) => {
				try {
					await interaction.deferReply({ ephemeral: false });

					const query = interaction.options.getString('query');
					const limit = interaction.options.getInteger('limit') || 5;
					const autoplay = interaction.options.getBoolean('autoplay') || false;
					logger.log(`Searching for: ${query} (autoplay: ${autoplay})`);

					// Notify user that search is in progress
					await interaction.editReply({
						content: `🔍 Searching Plex library for "${query}"... This may take up to 30 seconds...`,
					});

					// Search for content
					const searchResults = await PlexAPI.search(query);

					if (!searchResults?.Metadata || searchResults.Metadata.length === 0) {
						return interaction.editReply({
							content: '❌ Could not find any movies matching that search.',
						});
					}

					// Limit results
					const results = searchResults.Metadata.slice(0, Math.min(limit, 10));

					// Build results embed
					const embed = new EmbedBuilder()
						.setColor(0xE5A00D)
						.setTitle(`🎬 Search Results for "${query}"`)
						.setDescription(`Found ${searchResults.Metadata.length} results (showing ${results.length})`)
						.setTimestamp();

					results.forEach((item, index) => {
						const year = item.year ? ` (${item.year})` : '';
						const summary = item.summary ? item.summary.substring(0, 100) + '...' : 'No description';

						// Detect content type from the metadata
						let typeEmoji = '🎬'; // Default to movie
						let typeLabel = '';
						if (item.type === 'show') {
							typeEmoji = '📺';
							typeLabel = ' [TV SHOW]';
						} else if (item.type === 'episode') {
							typeEmoji = '📺';
							typeLabel = ' [EPISODE]';
						} else if (item.type === 'movie') {
							typeEmoji = '🎬';
							typeLabel = ' [MOVIE]';
						}

						embed.addFields({
							name: `${index + 1}. ${typeEmoji} ${item.title}${year}${typeLabel}`,
							value: summary,
							inline: false,
						});
					});

					embed.addFields({
						name: '📌 Available Controls via Discord',
						value:
							'• `/play <query> autoplay:true` - Search and queue content (with optional autoplay)\n' +
							'• `/skip` - Skip to next episode/movie in queue\n' +
							'• `/previous` - Go to previous episode/movie in queue\n' +
							'• `/pause` - Pause playback\n' +
							'• `/resume` - Resume playback\n' +
							'**Browser shortcuts:** Spacebar = Play/Pause, Arrow Keys = Seek ⏩/⏪',
						inline: false,
					});

					// Create play queue for first result
					const firstMovie = results[0];

					try {
						logger.log(`Playing: ${firstMovie.title} (type: ${firstMovie.type})`);
						await PlexAPI.playMedia(firstMovie.key);

						embed.setFooter({
							text: `▶️ Playing: ${firstMovie.title}`,
						});

						// Always try to send play and fullscreen commands via WebSocket
						try {
							const wsClient = await getWebSocketClient();
							if (wsClient.isReady()) {
								logger.log('Sending play command');
								// Send play command
								await wsClient.sendCommand({ action: 'play' });
								logger.log('Play command sent successfully');

								// Add a small delay before fullscreen to ensure video element is ready
								await new Promise(resolve => setTimeout(resolve, 500));

								logger.log('Sending fullscreen command');
								// Send fullscreen command - extension will click fullscreen button or press F
								await wsClient.sendCommand({ action: 'fullscreen' });
								logger.log('Fullscreen command sent successfully');

								embed.addFields({
									name: '▶️ Playback Started',
									value: 'Video playing in fullscreen via Firefox extension',
									inline: false,
								});

								logger.log('Playback and fullscreen activated successfully');
							} else {
								logger.warn('WebSocket not ready - extension not connected');
								embed.addFields({
									name: '⚠️ Connection Note',
									value: 'Firefox extension not connected. Content queued to Plex - use `/resume` to start playback or press F for fullscreen.',
									inline: false,
								});
							}
						} catch (wsError) {
							logger.warn(`WebSocket command failed: ${wsError.message}`);
							embed.addFields({
								name: '⚠️ Partial Control',
								value: `Content queued to Plex successfully, but Firefox extension control unavailable. Manual playback required.`,
								inline: false,
							});
						}

						return interaction.editReply({ embeds: [embed] });
					} catch (playError) {
						// Queue creation might fail, but search results are still useful
						logger.warn(`Queue creation failed: ${playError.message}`);

						embed.setFooter({
							text: `⚠️ Found results but queue creation failed. Search results shown above.`,
						});

						return interaction.editReply({ embeds: [embed] });
					}
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

export default PlayCommand;