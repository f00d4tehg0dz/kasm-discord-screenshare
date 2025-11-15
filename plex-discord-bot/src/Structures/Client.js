import { Client, Collection, IntentsBitField, REST, Routes } from 'discord.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import fs from 'fs';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Extended Discord.js Client with command and event handlers
 */
class PlexBot extends Client {
	constructor(options = {}) {
		super({
			intents: [
				IntentsBitField.Flags.Guilds,
				IntentsBitField.Flags.GuildMembers,
				IntentsBitField.Flags.GuildMessages,
				IntentsBitField.Flags.MessageContent,
				IntentsBitField.Flags.DirectMessages,
			],
			...options,
		});

		/**
		 * @type {Collection<string, import('./Command.js').default>}
		 */
		this.commands = new Collection();

		/**
		 * @type {Collection<string, import('./Event.js').default>}
		 */
		this.events = new Collection();

		this.logger = {
			log: (msg) => console.log(`[LOG] ${msg}`),
			error: (msg) => console.error(`[ERROR] ${msg}`),
			warn: (msg) => console.warn(`[WARN] ${msg}`),
			success: (msg) => console.log(`[SUCCESS] ${msg}`),
		};
	}

	/**
	 * Load all commands from the Commands directory
	 */
	async loadCommands() {
		const commandsDir = path.join(__dirname, '../Commands');

		if (!fs.existsSync(commandsDir)) {
			this.logger.warn(`Commands directory not found at ${commandsDir}`);
			return;
		}

		const commandFiles = fs.readdirSync(commandsDir).filter(file => file.endsWith('.js'));

		for (const file of commandFiles) {
			try {
				const filePath = path.join(commandsDir, file);
				const fileUrl = new URL(`file://${filePath.replace(/\\/g, '/')}`).href;
				const { default: CommandClass } = await import(fileUrl);
				const command = new CommandClass();

				if (!command.name || !command.run) {
					this.logger.warn(`Command file ${file} missing name or run property`);
					continue;
				}

				this.commands.set(command.name, command);
				this.logger.success(`Command loaded: ${command.name}`);
			} catch (error) {
				this.logger.error(`Failed to load command ${file}: ${error.message}`);
			}
		}
	}

	/**
	 * Load all events from the Events directory
	 */
	async loadEvents() {
		const eventsDir = path.join(__dirname, '../Events');

		if (!fs.existsSync(eventsDir)) {
			this.logger.warn(`Events directory not found at ${eventsDir}`);
			return;
		}

		const eventFiles = fs.readdirSync(eventsDir).filter(file => file.endsWith('.js'));

		for (const file of eventFiles) {
			try {
				const filePath = path.join(eventsDir, file);
				const fileUrl = new URL(`file://${filePath.replace(/\\/g, '/')}`).href;
				const { default: EventClass } = await import(fileUrl);
				const event = new EventClass();

				if (!event.event || !event.run) {
					this.logger.warn(`Event file ${file} missing event or run property`);
					continue;
				}

				if (event.once) {
					this.once(event.event, event.run.bind(null, this));
				} else {
					this.on(event.event, event.run.bind(null, this));
				}

				this.events.set(event.event, event);
				this.logger.success(`Event loaded: ${event.event}`);
			} catch (error) {
				this.logger.error(`Failed to load event ${file}: ${error.message}`);
			}
		}
	}

	/**
	 * Register all slash commands with Discord
	 */
	async registerSlashCommands() {
		const slashCommands = this.commands
			.filter(cmd => ['BOTH', 'SLASH'].includes(cmd.type))
			.map(cmd => ({
				name: cmd.name.toLowerCase(),
				description: cmd.description,
				options: cmd.slashCommandOptions || [],
				defaultMemberPermissions: cmd.permission ? [cmd.permission] : null,
				dmPermission: false,
			}));

		try {
			const rest = new REST({ version: '10' }).setToken(process.env.TOKEN);

			await rest.put(
				Routes.applicationCommands(process.env.CLIENT_ID),
				{ body: slashCommands }
			);

			this.logger.success(`Registered ${slashCommands.length} slash commands`);
		} catch (error) {
			this.logger.error(`Failed to register slash commands: ${error.message}`);
		}
	}

	/**
	 * Start the bot
	 */
	async start() {
		try {
			await this.loadCommands();
			await this.loadEvents();
			await this.login(process.env.TOKEN);
		} catch (error) {
			this.logger.error(`Failed to start bot: ${error.message}`);
			process.exit(1);
		}
	}
}

export default PlexBot;