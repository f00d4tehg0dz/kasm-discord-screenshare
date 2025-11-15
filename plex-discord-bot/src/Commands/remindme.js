import Command from '../Structures/Command.js';
import { EmbedBuilder } from 'discord.js';

// Simple in-memory reminder storage
const reminders = new Map();

// Parse time strings like "10m", "10s", "10d"
function parseTime(timeStr) {
	const units = { s: 1000, m: 60000, h: 3600000, d: 86400000 };
	const match = timeStr.match(/^(\d+)([smhd])$/);
	if (!match) return null;
	return parseInt(match[1]) * units[match[2]];
}

class RemindmeCommand extends Command {
	constructor() {
		super({
			name: 'remindme',
			description: 'Remind me at a later date',
			type: 'SLASH',
			slashCommandOptions: [
				{
					name: 'time',
					description: 'Time until reminder (e.g., 10m, 1h, 2d)',
					type: 3, // STRING type
					required: true,
				},
				{
					name: 'reason',
					description: 'What to remind you about',
					type: 3, // STRING type
					required: true,
				},
			],
			run: async (client, interaction) => {
				try {
					const userId = interaction.user.id;
					const time = interaction.options.getString('time');
					const reason = interaction.options.getString('reason');

					// Check if user already has a reminder
					if (reminders.has(userId)) {
						return interaction.reply({
							content: '❌ You already have a saved reminder! Wait for it or use another account.',
							ephemeral: true,
						});
					}

					// Parse time
					const delay = parseTime(time);
					if (!delay) {
						return interaction.reply({
							content: '❌ Invalid time format. Use: 10s, 10m, 1h, 2d',
							ephemeral: true,
						});
					}

					// Store reminder
					const reminderTime = Date.now() + delay;
					reminders.set(userId, { reason, reminderTime, interaction });

					// Create confirmation embed
					const confirmEmbed = new EmbedBuilder()
						.setColor(0x51267)
						.setDescription(`✅ Reminder set for **${interaction.user.tag}**\nReason: ${reason}`)
						.setTimestamp();

					await interaction.reply({ embeds: [confirmEmbed] });

					// Wait for reminder time
					setTimeout(async () => {
						try {
							const reminderEmbed = new EmbedBuilder()
								.setColor(0x51267)
								.setDescription(`⏰ **Reminder:** ${reason}`)
								.setTimestamp();

							// Try to send DM
							await interaction.user.send({ embeds: [reminderEmbed] });
						} catch (error) {
							console.error(`Failed to send reminder DM to ${interaction.user.tag}:`, error.message);
						} finally {
							reminders.delete(userId);
						}
					}, delay);
				} catch (error) {
					console.error('RemindMe command error:', error);
					return interaction.reply({
						content: `❌ Error: ${error.message}`,
						ephemeral: true,
					});
				}
			},
		});
	}
}

export default RemindmeCommand;