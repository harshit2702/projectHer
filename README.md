# ✨ projectHer ✨

Hey! This is **projectHer** — a super personal AI companion app for iOS. I got tired of AI forgetting everything I said after like five minutes, so I built this. It's basically a chat app where the AI (we call her Pandu ❤️) actually remembers your vibes, your plans, and all the random stuff you tell her. 

No more "goldfish memory" AI! 🧠

## 🚀 What it Does (The Cool Stuff)

- **💬 Real Chats:** A super clean chat UI that feels smooth. You can talk to Pandu about anything.
- **🧠 Infinite Memory:** This is the big one. Pandu doesn't just "forget." She saves "memories" about your preferences, your identity, and even how you're feeling.
- **📊 Memory Dashboard:** You can literally go into her "brain" and see what she's remembered. It shows stats on how many things she knows about you and what's currently on her mind.
- **🔗 Linking Memories:** You can manually link messages to memories if you want her to really connect the dots. 
- **✅ Future Planning:** If you tell her about something you want to do, she can track it as a "future plan." You can even mark them as completed right in the chat!
- **🌐 Connection Health:** A little indicator that shows if the backend is vibe-ing or if it's down.
- **🌙 Looks Great:** Styled with a nice mix of blue and pink, because why not?

## 📂 The Boring (But Important) Stuff

Here’s how the project is set up:

- `projectHer/`: All the magic happens here.
  - `ContentView.swift`: The main chat screen where all the talking happens.
  - `MemoryDashboardView.swift`: The "brain" view.
  - `BackgroundManager.swift`: Keeps things running in the background so you get notifications.
  - `AppConfig.swift`: Where the server URLs and keys live.
  - `MemoryModels.swift`: The database stuff (SwiftData is amazing).
- `projectHer.xcodeproj/`: The Xcode project file.

## 🛠️ Requirements

- You'll need an iPhone or Simulator running **iOS 17.0+**.
- **Xcode 15.0+** is required because we're using the latest Swift features.
- A bit of patience if the server is sleeping lol.

## 🖥️ The Backend

So, the app needs a brain to talk to. I'm using a Python backend for all the AI processing.

> **⚠️ Heads up:** I'm going to upload the `server.py` and all the backend info really soon. Stay tuned!

## ⚡ Setup

1. Grab the code and open `projectHer.xcodeproj`.
2. Make sure you've got your development team set up in Xcode.
3. Check `AppConfig.swift` and make sure the `serverURL` is pointing to where your backend is running.
4. Hit that **Run** button and start chatting!

## 📜 License

This is MIT licensed. It's open source, so do whatever you want with it! Just remember there's **no liability**—if it breaks, it's on you (but it shouldn't, hopefully!). See the [LICENSE](LICENSE) file for the legal-ish details.

---
*Made with ❤️ and way too much caffeine.*