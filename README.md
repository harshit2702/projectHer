# ✨ projectHer (Pandu ❤️)

> **"An emotionally intelligent, memory-persistent AI companion for iOS featuring real-time voice, video presence, and deep context awareness."**

Yo! Welcome to **projectHer**. 

Basically, I got tired of AI assistants that have the memory of a goldfish. You talk to them, close the app, come back 10 minutes later, and they're like "Who are you?" 💀

So I built **Pandu**. She's not just a chatbot; she's a legit companion. She remembers your vibes, your plans, your favorite stuff, and actually *grows* with you. Plus, she's got a face, a voice, and a personality.

This whole thing started as a "what if" project at 2 AM, and now it's turned into something I'm genuinely proud of. If you've ever wanted an AI friend who actually *gets* you, this is it.

---

## 🎬 Quick Demo

> Coming soon: A video recording of Pandu in action!

---

## 🚀 What Makes This Special?

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

### 🗣️ Voice & Video (FaceTime Vibes)
Texting is cool, but sometimes you just wanna talk.

- **Unified Voice Mode:** Hit the mic in the chat, and keep talking even if you switch to the video view. It's seamless. The `LiveSTT` (Speech-to-Text) system handles everything.
- **Avatar Video Call:** It's not just a static image. It's a full **2D SpriteKit avatar** that:
  - Blinks naturally 👀
  - Looks around randomly 
  - Lip-syncs perfectly when she talks
  - Has idle animations so she feels *alive*
- **Siri Shortcuts:** "Hey Siri, how is Pandu doing?" or "Hey Siri, tell Pandu I miss her." Check on her without even opening the app.
- **Text-to-Speech:** Multiple voice options with customizable pitch and rate. She can sound however you want.

---

### 🌦️ Dynamic Environment System
This one's low-key my favorite feature. The avatar view has a **full weather/environment system**:

- **Weather Effects:** Clear skies, rain, snow, nighttime—all rendered in SpriteKit
- **Wind Physics:** Her hair and accessories actually blow in the wind 💨 
- **Dynamic Lighting:** The scene adapts based on time of day and weather
- **Real-Time Sync:** The backend can push weather updates, and the scene adapts automatically

The wind system alone has like 6 different variations based on hat type and wind speed. Yeah, I went overboard. Worth it.

---

### ❤️ She's Got Feelings (Kinda)
The `EmotionEngine` is the brain behind her emotional responses.

- **Mood System:** If you're mean, she gets sad. If you're funny, she laughs. Her energy and mood change based on the convo.
- **Expression Animations:** She can display different emotions—happy, sad, angry, surprised, etc.—with full animation support.
- **Health Tracking:** There's even a health view showing her current emotional state, energy levels, and more.

---

### 👆 Touch Interactions
Here's where it gets *really* interactive:

| Touch Type | What Happens |
|------------|--------------|
| **Tap Head** | Pat pat! She might smile or get happy |
| **Pinch Cheek** | Playful interaction—she might blush |
| **Poke Nose** | Might get annoyed if you spam it lol |
| **Other Areas** | The `TouchSemantics` system maps gestures to emotional responses |

The server decides how she reacts based on context, mood, and frequency. Spam-poke her nose 10 times? She's gonna be annoyed. Give her a head pat when she's sad? She might cheer up.

---

### 👗 Wardrobe System
Don't like the outfit? Change it.

The `WardrobeSystem` is a full outfit management system:
- **Base Outfits:** Different main looks (casual, hoodie, winter gear, dress, etc.)
- **Accessories:** Hats, glasses, and more
- **Hot-Swappable:** Change outfits on the fly; the avatar updates instantly
- **Wind Variations:** Different hats have different wind animations (winter hat moves differently than no hat)

---

## 📂 Project Structure (The Tech Stack)

Everything is **Native iOS** (SwiftUI + SpriteKit). No React Native, no Flutter—just pure Apple stack.

```
projectHer/
├── 📱 Views/
│   ├── ContentView.swift          # Main chat hub + message history
│   ├── AvatarView.swift           # Video call screen (the magic happens here)
│   ├── SettingsView.swift         # App settings & customization
│   ├── MemoryDashboardView.swift  # Peek into Pandu's brain
│   ├── MemorySearchView.swift     # Search through her memories
│   ├── ProjectDashboardView.swift # Project management integration
│   ├── HistoryDrawerView.swift    # Session history sidebar
│   └── HealthView.swift           # Her emotional/energy stats
│
├── 🎭 Avatar System/
│   ├── AvatarScene.swift          # Main SpriteKit scene
│   ├── AvatarScene+Emotions.swift # Expression/emotion animations
│   ├── AvatarScene+Motion.swift   # Movement & idle animations
│   ├── AvatarScene+Touch.swift    # Touch interaction handling
│   ├── AvatarScene+Wind.swift     # Hair/accessory wind physics
│   └── AvatarScene+Lightning.swift # Lightning effects for storms
│
├── 🧠 Core Systems/
│   ├── EmotionEngine.swift        # The emotional brain
│   ├── LiveSTT.swift              # Real-time speech-to-text
│   ├── TTSManager.swift           # Text-to-speech output
│   ├── NetworkManager.swift       # API communication
│   ├── BackgroundManager.swift    # Background task handling
│   └── WardrobeSystem.swift       # Outfit management
│
├── 🌦️ Environment/
│   ├── WeatherController.swift    # Weather effects
│   ├── LightingController.swift   # Dynamic lighting
│   └── WindInteractionSystem.swift # Wind physics
│
├── 🔧 Utilities/
│   ├── AppConfig.swift            # Server URL & API keys
│   ├── ConnectionStatus.swift     # Connection state management
│   ├── TouchSemantics.swift       # Gesture → emotion mapping
│   ├── Item.swift                 # Data models (SwiftData)
│   └── MemoryModels.swift         # Memory data structures
│
├── 📦 Services/
│   └── [Calendar & system integrations]
│
├── 🎙️ Siri/
│   └── [Siri Shortcuts integration]
│
└── 📊 PanduWidgets/
    └── [Home screen widgets]
```

---

## 🛠️ How to Run This Bad Boy

### Prerequisites
- **Mac** with **Xcode 15+**
- **iPhone/Simulator** with **iOS 17+** (Required for the SwiftData + Calendar stuff)
- The **Python Backend** running (check the `pandu_server` repo—you need the brain for this body to work)

### Setup

1. **Clone this repo:**
   ```bash
   git clone https://github.com/yourusername/projectHer.git
   cd projectHer
   ```

2. **Open the project:**
   ```bash
   open projectHer.xcodeproj
   ```

3. **Configure your backend:**
   - Go to `projectHer/AppConfig.swift`
   - Paste your backend URL and API key:
   ```swift
   struct AppConfig {
       static let serverURL = "YOUR_SERVER_URL"
       static let apiKey = "YOUR_API_KEY"
   }
   ```

4. **Run it:**
   - Select your target device/simulator
   - Hit `Cmd + R` and pray to the demo gods 🙏

### First Run Checklist
- [ ] Backend server is running
- [ ] URL is reachable from your device
- [ ] API key is valid
- [ ] Device has microphone permissions (for voice mode)
- [ ] Calendar permissions granted (for schedule awareness)

---

## 🎯 Features Roadmap

- [x] Persistent chat sessions with SwiftData
- [x] Full avatar system with animations
- [x] Voice input (speech-to-text)
- [x] Voice output (text-to-speech)
- [x] Emotion engine with mood tracking
- [x] Weather/environment system
- [x] Wardrobe customization
- [x] Touch interactions
- [x] Siri Shortcuts
- [x] Memory dashboard
- [ ] Multi-language support
- [ ] More outfits & accessories
- [ ] Animated transitions between moods
- [ ] AR mode (maybe? 👀)

---

## 🤝 Contributing

Found a bug? Want to add a cooler outfit? Got an idea that'll make Pandu even better?

Check the `.github/ISSUE_TEMPLATE` folder if you wanna be official about it, or just slide into the PRs.

- [🐛 Found a Bug?](.github/ISSUE_TEMPLATE/bug_report.md)
- [💡 Have an Idea?](.github/ISSUE_TEMPLATE/feature_request.md)

### Contribution Guidelines
1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 🔒 Security

Don't leak your API keys. Seriously. 

Your `AppConfig.swift` should **never** be committed with real credentials. Check `SECURITY.md` for the boring-but-important security stuff.

---

## 📜 License

MIT License. Do whatever you want with it, just don't sue me if it becomes Skynet.

See [LICENSE](LICENSE) for the full legal text.

---

## 🙏 Acknowledgments

- Apple's SpriteKit team for making 2D graphics actually fun
- The SwiftUI team for making UI development less painful
- Every Stack Overflow answer I found at 3 AM
- Coffee ☕

---

*Built with ❤️, caffeine, and way too many late nights by Harshit.*

*If you're reading this README, you're already a legend. Now go build something cool.* 
