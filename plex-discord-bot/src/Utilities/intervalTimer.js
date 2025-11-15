/**
 * Interval Timer Utility
 * Manages periodic tasks for the Discord bot
 * Note: Reminders are now handled directly in the remindme command
 * This file is kept for future use of interval-based utilities
 */

export const startIntervalTimer = (client) => {
	// Example: Check something every 60 seconds
	const checkInterval = setInterval(async () => {
		try {
			// Add periodic checks here if needed
			// For example: check Plex server health, rotate status, etc.
			// console.log('[IntervalTimer] Running periodic checks...');
		} catch (error) {
			console.error('[IntervalTimer] Error during interval check:', error);
		}
	}, 60000); // Run every 60 seconds

	// Store interval ID for cleanup if needed
	if (!client.intervals) {
		client.intervals = [];
	}
	client.intervals.push(checkInterval);

	console.log('[IntervalTimer] Interval timer started');

	// Return function to stop all intervals
	return () => {
		if (client.intervals) {
			client.intervals.forEach(interval => clearInterval(interval));
			client.intervals = [];
			console.log('[IntervalTimer] All intervals cleared');
		}
	};
};

export default startIntervalTimer;