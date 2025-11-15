import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';

/**
 * Help Command - Shows available Plex Discord Bot commands
 */
class HelpCommand extends Command {
	constructor() {
		super({
			name: 'help',
			description: 'Show all available Plex Discord Bot commands',
			type: 'SLASH',
			run: async (client, interaction) => {
				const embed = new EmbedBuilder()
					.setColor(0x51267)
					.setTitle('🎬 Plex Discord Bot - Command Help')
					.setDescription(
						'A Discord bot for searching and queueing movies from your Plex Media Server'
					)
					.addFields(
						{
							name: '🔍 Search & Queue',
							value:
								'`/play <query>`\n' +
								'Search for a movie and queue it to your Plex playlist\n' +
								'Use `/play query:Title limit:10` to see more results\n\n' +
								'`/start`\n' +
								'Create a new shuffled playlist queue from your library',
							inline: false,
						},
						{
							name: '📊 Status & Info',
							value:
								'`/status`\n' +
								'Check your Plex server configuration and connection\n\n' +
								'`/remindme <time> <reason>`\n' +
								'Set a reminder (e.g., `/remindme time:30m reason:Watch movie`)',
							inline: false,
						},
						{
							name: '⚠️ Playback Control - NOT Available',
							value:
								'❌ `/skip`, `/pause`, `/resume`\n' +
								'These commands are **NOT available** for Firefox web browsers.\n\n' +
								'**Why?** Plex API only supports remote control for dedicated player apps.\n\n' +
								'**Workaround:** Use Firefox keyboard controls:\n' +
								'• **Spacebar** = Play/Pause\n' +
								'• **Arrow Keys** = Seek forward/backward\n' +
								'• **F** = Full screen',
							inline: false,
						},
						{
							name: '📌 How to Use This Bot',
							value:
								'1. Use `/play` to search for movies\n' +
								'2. Watch search results in Discord\n' +
								'3. The first result will be added to your queue\n' +
								'4. Go to your Plex web player (Firefox)\n' +
								'5. Refresh to load the new queue\n' +
								'6. Use Firefox controls to play/pause/seek',
							inline: false,
						},
						{
							name: '💡 Pro Tips',
							value:
								'• Use `/start` to queue a shuffled playlist\n' +
								'• Use `/play` with specific titles for exact matches\n' +
								'• Your Plex server must be running and accessible\n' +
								'• Keep your Firefox Plex tab refreshed for latest queue',
							inline: false,
						}
					)
					.setFooter({
						text: 'Plex Discord Bot | Type /help to see this message again',
					})
					.setTimestamp();

				return await interaction.reply({ embeds: [embed], ephemeral: true });
			},
		});
	}
}

export default HelpCommand;
