# API Keys Configuration

Some of the new Discord bot commands require API keys. Here's how to set them up:

## Commands and Required API Keys

### 1. `/dadjoke` - Dad Joke Command
- **API**: icanhazdadjoke.com
- **API Key**: Not required
- **Status**: ✅ Works without API key

### 2. `/joke` - Random Joke Command
- **API**: API Ninjas (https://www.api-ninjas.com/api/jokes)
- **API Key**: `API_NINJAS_KEY` (optional, defaults to 'demo')
- **Setup**:
  1. Visit https://www.api-ninjas.com
  2. Sign up for a free account
  3. Get your API key from your dashboard
  4. Add to `.env` file:
     ```
     API_NINJAS_KEY=your_api_key_here
     ```

### 3. `/catpic` - Cat Picture Command
- **API**: TheCatAPI (https://thecatapi.com)
- **API Key**: `CAT_API_KEY` (optional, but recommended)
- **Setup**:
  1. Visit https://developers.thecatapi.com/
  2. Sign up for a free account
  3. Generate an API key
  4. Add to `.env` file:
     ```
     CAT_API_KEY=your_api_key_here
     ```

### 4. `/dogpic` - Dog Picture Command
- **API**: Dog.ceo (https://dog.ceo/dog-api/)
- **API Key**: Not required
- **Status**: ✅ Works without API key

## Adding to .env File

Edit your `.env` file in the `plex-discord-bot` directory:

```bash
# Existing variables...
DISCORD_TOKEN=your_discord_token
GUILD_ID=your_guild_id
ROLE_ID=your_role_id

# New API Keys (optional)
API_NINJAS_KEY=your_api_ninjas_key
CAT_API_KEY=your_cat_api_key
```

## Testing the Commands

After setting up API keys and restarting the bot, test each command:

```
/dadjoke    - Get a random dad joke
/joke       - Get a random joke (requires API Ninjas key for unlimited requests)
/catpic     - Get a random cat picture
/dogpic     - Get a random dog picture
```

## Rate Limits

- **icanhazdadjoke.com**: No rate limit (public API)
- **API Ninjas**: Free tier has rate limits, upgrade for more
- **TheCatAPI**: Free tier allows limited requests, upgrade for more
- **Dog.ceo**: No rate limit (public API)

## Troubleshooting

If a command fails:

1. Check the bot logs for error messages
2. Verify your API key is correct
3. Check if the API service is online
4. Verify your internet connection
5. Make sure the API key has the right permissions

For API-specific issues, check the API documentation at the links above.
