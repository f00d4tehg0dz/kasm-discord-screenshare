/**
 * Check if a user has permission to execute a command
 * @param {import('discord.js').CommandInteraction} interaction
 * @param {string|null} requiredRole Role ID required
 * @param {string[]} allowedUsers Array of user IDs with bypass permission
 * @returns {boolean} True if user has permission
 */
export function hasPermission(interaction, requiredRole = null, allowedUsers = []) {
	// Check if user is in allowed list
	if (allowedUsers.includes(interaction.user.id)) {
		return true;
	}

	// Check role if required
	if (requiredRole && !interaction.member?.roles?.cache?.has(requiredRole)) {
		return false;
	}

	return true;
}

/**
 * Get a formatted permission denied message
 * @returns {Object} Embed-ready message object
 */
export function getPermissionDeniedMessage() {
	return {
		content: '❌ You do not have permission to use this command.',
		ephemeral: true,
	};
}