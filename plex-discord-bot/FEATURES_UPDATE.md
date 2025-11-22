# Discord Bot New Features - Fullscreen & ChatGPT Suggestions

## 🎬 Feature 1: Automatic Fullscreen on Play Command

### What Changed
The `/play` command now automatically activates fullscreen when queuing content to your Plex player.

### How It Works
1. When you run `/play <query>`, the bot searches for content
2. The first result is automatically queued to Plex
3. **NEW:** The bot sends a play command AND a fullscreen command via the Firefox extension
4. Video starts playing in fullscreen automatically (if Firefox extension is connected)

### Requirements
- Firefox extension must be installed and connected
- Plex web player must be active

### Behavior
- ✅ **With Firefox Extension Connected:** Video plays in fullscreen immediately
- ⚠️ **Extension Not Connected:** Content is queued, user can manually press F for fullscreen

### Example Usage
```
/play query:Inception
```
**Result:** Inception queues and plays in fullscreen

---

## 🤖 Feature 2: ChatGPT-Powered Suggestions

### What Is It?
A new `/suggest` command that uses ChatGPT to recommend movies and TV shows based on your mood and genre preferences.

### How It Works
1. Run `/suggest mood:"scary" genre:"horror"`
2. ChatGPT analyzes your preferences and suggests 5 titles
3. The bot searches your Plex library for each suggestion
4. You see a beautiful embed with all 5 options
5. **Select one using the dropdown menu**
6. The selected title plays in fullscreen automatically!

### Requirements
- **OpenAI API Key** (for ChatGPT integration)
- Get one at: https://platform.openai.com/api-keys
- Add to `.env` file: `OPENAI_API_KEY=your_key_here`

### Features
- ✅ ChatGPT generates personalized suggestions
- ✅ Bot searches your Plex library for matches
- ✅ Shows which titles are in your library (✅) and which aren't (⚠️)
- ✅ Click dropdown to select and play
- ✅ Automatically plays in fullscreen
- ✅ Fallback suggestions if ChatGPT fails
- ✅ Works with any mood/genre combination

### Mood Examples
- `scary` - Horror recommendations
- `funny` - Comedy recommendations
- `action-packed` - Action movie recommendations
- `romantic` - Romance suggestions
- `thought-provoking` - Intellectual cinema
- `relaxing` - Chill content
- **Any custom mood you want!**

### Example Usage

**With ChatGPT:**
```
/suggest mood:scary genre:horror
```
**Result:** ChatGPT suggests 5 horror movies like:
1. The Shining
2. Hereditary
3. The Conjuring
4. Insidious
5. Stranger Things

**Without ChatGPT (Fallback):**
If your OpenAI API key isn't set, the bot uses smart fallback suggestions based on mood.

### Fallback Moods Available
- `scary` - Horror titles
- `funny` - Comedy titles
- `action` - Action titles
- `romantic` - Romance titles
- **Any other mood** - Gets mixed popular titles

### Selection Process
1. View the embed with 5 suggestions
2. Scroll through the dropdown menu
3. Select your choice
4. Bot checks if it's in your Plex library:
   - **In Library:** Queues and plays in fullscreen
   - **Not in Library:** Shows friendly message suggesting you add it

### Files Modified/Created

**Modified:**
- `src/Commands/play.js` - Added fullscreen command
- `src/Events/interactionCreate.js` - Added select menu handler

**Created:**
- `src/Commands/suggest.js` - New ChatGPT suggestion command

---

## 📋 Setup Instructions

### 1. For Fullscreen (No Setup Needed!)
The fullscreen feature works automatically with your existing Firefox extension. No additional configuration needed!

### 2. For ChatGPT Suggestions

#### Get Your OpenAI API Key
1. Go to https://platform.openai.com/api-keys
2. Sign in with your OpenAI account (create one if needed)
3. Click "Create new secret key"
4. Copy the key

#### Add to .env File
```bash
# In plex-discord-bot/.env
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxx
```

#### Restart Bot
```bash
npm restart
# or however you restart your bot
```

#### Test It
```
/suggest mood:funny genre:comedy
```

---

## 🎮 Command Reference

### `/play <query> [limit] [autoplay]`
Search and queue content with automatic fullscreen

**Parameters:**
- `query` - Movie/show title (required)
- `limit` - Results to show (1-10, default: 5)
- `autoplay` - Auto-play first result (true/false)

**Example:**
```
/play query:Inception limit:5 autoplay:true
```

---

### `/suggest <mood> [genre]`
Get ChatGPT AI suggestions based on your preferences

**Parameters:**
- `mood` - Your current mood (required)
- `genre` - Preferred genre (optional)

**Examples:**
```
/suggest mood:scary genre:horror
/suggest mood:funny
/suggest mood:action-packed genre:superhero
/suggest mood:thought-provoking
```

---

## ⚙️ Environment Variables

Add these to your `.env` file in `plex-discord-bot/`:

```bash
# Required for Discord bot
DISCORD_TOKEN=your_token
GUILD_ID=your_guild_id

# Optional but recommended - for ChatGPT suggestions
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxx

# Optional - for external joke API
API_NINJAS_KEY=your_key
CAT_API_KEY=your_key
```

---

## 🐛 Troubleshooting

### Fullscreen Not Working?
- ✅ Check Firefox extension is connected and active
- ✅ Verify Plex web player is open in Firefox
- ✅ Check browser console for errors (F12)

### ChatGPT Suggestions Failing?
- ✅ Verify `OPENAI_API_KEY` is set in `.env`
- ✅ Check OpenAI API account has active credits
- ✅ Verify API key is correct (no extra spaces)
- ✅ Check bot logs for error messages

### Suggestion Not in Library?
- ✅ The title exists but isn't in your Plex library
- ✅ Add it to your Plex library and it will work!
- ✅ Movie title might be slightly different in Plex (e.g., "Inception" vs "Inception (2010)")

### Select Menu Not Showing?
- ✅ Make sure bot has permission to send messages
- ✅ Check the suggestion command ran successfully
- ✅ Try the command again

---

## 💡 Pro Tips

1. **Be Specific with Moods:** "scary supernatural horror" gets better results than just "scary"
2. **Use Genres:** Adding a genre narrows suggestions: `/suggest mood:funny genre:comedy`
3. **Check Library First:** Some suggestions might not be in your library yet
4. **Fullscreen Works Best:** Keep Firefox in focus for automatic fullscreen
5. **Fallback Works Great:** Even without API key, you get smart suggestions!

---

## 📊 How It Works Behind the Scenes

### Fullscreen Flow
```
User runs /play
  ↓
Bot searches Plex
  ↓
Bot queues first result
  ↓
Bot sends play command (WebSocket)
  ↓
Bot sends fullscreen command (WebSocket)
  ↓
Firefox extension activates fullscreen
  ↓
Video plays in fullscreen!
```

### ChatGPT Suggestion Flow
```
User runs /suggest
  ↓
Bot calls ChatGPT API
  ↓
ChatGPT suggests 5 titles
  ↓
Bot searches Plex for each title
  ↓
Bot creates dropdown menu with 5 options
  ↓
User selects an option
  ↓
Bot queues selection
  ↓
Bot sends play + fullscreen commands
  ↓
Video plays in fullscreen!
```

---

## 🚀 That's It!

Both features are now ready to use. Restart your bot and start enjoying automatic fullscreen playback and AI-powered content recommendations!

Questions? Check the bot logs or refer to the troubleshooting section above.
