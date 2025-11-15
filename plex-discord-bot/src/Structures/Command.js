/**
 * Base Command class for all bot commands
 * @typedef {'BOTH' | 'SLASH' | 'TEXT'} CommandType
 */
class Command {
	/**
	 * @param {Object} options Command options
	 * @param {string} options.name Command name (lowercase)
	 * @param {string} options.description Command description for slash commands
	 * @param {string} [options.permission] Required Discord permission
	 * @param {CommandType} [options.type='SLASH'] Command type (BOTH, SLASH, or TEXT)
	 * @param {import('discord.js').ApplicationCommandOption[]} [options.slashCommandOptions=[]] Slash command options
	 * @param {Function} options.run Async function to execute the command
	 */
	constructor(options) {
		this.name = options.name;
		this.description = options.description;
		this.permission = options.permission || null;
		this.type = ['BOTH', 'SLASH', 'TEXT'].includes(options.type) ? options.type : 'SLASH';
		this.slashCommandOptions = options.slashCommandOptions || [];
		this.run = options.run;
	}
}

export default Command;