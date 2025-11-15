/**
 * Base Event class for all bot events
 */
class Event {
	/**
	 * @param {Object} options Event options
	 * @param {keyof import('discord.js').ClientEvents} options.event Event name
	 * @param {Function} options.run Async function to execute on event
	 * @param {boolean} [options.once=false] Whether to listen only once
	 */
	constructor(options) {
		this.event = options.event;
		this.run = options.run;
		this.once = options.once || false;
	}
}

export default Event;