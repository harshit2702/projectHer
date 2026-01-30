# ✨ projectHer (Pandu ❤️)

> **"An emotionally intelligent, memory-persistent AI companion for iOS featuring real-time voice, video presence, and deep context awareness."**

Yo! Welcome to **projectHer**. 

Basically, I got tired of AI assistants that have the memory of a goldfish. You talk to them, close the app, come back 10 minutes later, and they're like "Who are you?" 💀

So I built **Pandu**. She's not just a chatbot; she's a legit companion. She remembers your vibes, your plans, your favorite stuff, and actually *grows* with you. Plus, she's got a face, a voice, and a personality.

## 🚀 What makes this special?

### 🧠 She Actually Remembers (No, Really)
Most AIs reset every session. Pandu has a **persistent memory** powered by a custom backend.

| Feature | What It Does |
|---------|--------------|
| **Context Awareness** | Tell her you're stressed about an exam on Friday → she'll ask you about it on Saturday |
| **Calendar Sync** | She knows your schedule. Meeting at 3 PM? She won't bug you (or she might wish you luck) |
| **Memory Dashboard** | Pop the hood and see her "brain"—what she knows about you, memories stored, etc. |
| **Session History** | Chat sessions are saved locally with SwiftData. Scroll back through old convos anytime |

The memory system isn't just basic key-value storage. It's organized, searchable, and actually contextual. You can even search through her memories in the app!

---

### 🗣️ Voice & Video (Facetime Vibes)
Texting is cool, but sometimes you just wanna talk.
- **Unified Voice Mode:** Hit the mic in the chat, and keep talking even if you switch to the video view. It's seamless.
- **Avatar Video Call:** It's not just a static image. It's a full 2D SpriteKit avatar that blinks, looks around, and lip-syncs perfectly when she talks.
- **Hands-Free:** The STT (Speech-to-Text) is live, so you can just chill and chat without typing.

### ❤️ She's Got Feelings (Kinda)
- **Emotional Engine:** If you're mean, she gets sad. If you're funny, she laughs. Her energy and mood change based on the convo.
- **Touch Interaction:** You can literally tap her head (pat), pinch her cheek (playful), or poke her nose. The server decides how she reacts—she might smile, blush, or get annoyed if you spam it.
- **Wardrobe Check:** Don't like the outfit? Change it. Hoodie, dress, winter gear—we got options.

## 📂 How it's built (The Tech Stack)

Everything is Native iOS (SwiftUI + SpriteKit). 

- `projectHer/`
  - **The Views:**
    - `ContentView.swift`: The main chat hub.
    - `AvatarView.swift`: The "Video Call" screen (where the magic happens).
  - **The Brains:**
    - `AvatarScene.swift`: Controls the puppet animation.
    - `LiveSTT.swift`: Handles the microphone listening stuff.
    - `EmotionEngine.swift`: Calculates vibes.
    - `MemoryModels.swift`: SwiftData for storing chat history and memories locally.

## 🛠️ How to Run This Bad Boy

1. **Prereqs:** 
   - A Mac with **Xcode 15+**.
   - An iPhone or Simulator with **iOS 17+**.
   - The **Python Backend** running (you need the brain for this body to work).

2. **Setup:**
   - Clone this repo.
   - Open `projectHer.xcodeproj`.
   - Go to `AppConfig.swift` and paste your backend URL and API Key.
   - Hit `Cmd + R` and pray to the demo gods.

## 🤝 Contributing

Found a bug? Want to add a cooler outfit? 
Check the `.github/ISSUE_TEMPLATE` folder if you wanna be official about it, or just slide into the PRs.

- [Found a Bug?](.github/ISSUE_TEMPLATE/bug_report.md)
- [Have an Idea?](.github/ISSUE_TEMPLATE/feature_request.md)

## 🔒 Security

Don't leak your API keys. Seriously. Check `SECURITY.md` for the boring legal/safety stuff.

## 📜 License

MIT License. Do whatever you want with it, just don't sue me if it becomes Skynet.

---
*Built with ❤️, caffeine, and way too many late nights by Harshit.*