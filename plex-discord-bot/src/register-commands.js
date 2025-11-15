import 'dotenv/config';
import { REST, Routes } from 'discord.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import fs from 'fs';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Auto-register slash commands from the Commands folder
 * This script dynamically loads all commands and registers them with Discord
 */
async function registerCommands() {
	try {
		console.log('[INFO] Loading commands from Commands folder...');

		const commandsDir = path.join(__dirname, 'Commands');
		const commandFiles = fs.readdirSync(commandsDir).filter(file => file.endsWith('.js'));

		const commands = [];

		for (const file of commandFiles) {
			const filePath = path.join(commandsDir, file);
			const { default: CommandClass } = await import(`file://${filePath}`);
			const command = new CommandClass();

			if (!command.name || !command.description) {
				console.warn(`[WARN] Command file ${file} missing name or description`);
				continue;
			}

			const commandData = {
				name: command.name.toLowerCase(),
				description: command.description,
			};

			if (command.slashCommandOptions && command.slashCommandOptions.length > 0) {
				commandData.options = command.slashCommandOptions;
			}

			commands.push(commandData);
			console.log(`[SUCCESS] Loaded command: ${command.name}`);
		}

		if (commands.length === 0) {
			console.warn('[WARN] No commands found to register');
			return;
		}

		console.log(`[INFO] Registering ${commands.length} commands with Discord...`);

		const rest = new REST({ version: '10' }).setToken(process.env.TOKEN);

		await rest.put(
			Routes.applicationCommands(process.env.CLIENT_ID),
			{ body: commands }
		);

		console.log(`[SUCCESS] Successfully registered ${commands.length} slash commands!`);
	} catch (error) {
		console.error(`[ERROR] Failed to register commands: ${error.message}`);
		process.exit(1);
	}
}

registerCommands();