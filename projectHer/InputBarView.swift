import SwiftUI

struct InputBarView: View {
    @Binding var inputText: String
    
    let isTyping: Bool
    let isSpeaking: Bool
    
    @Binding var voiceMode: Bool
    let transcript: String
    let isListening: Bool
    
    let onSendText: () -> Void
    let onEnterVoiceMode: () -> Void
    let onToggleMic: () -> Void
    let onCancelVoice: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        if voiceMode {
            VStack(spacing: 8) {
                Text(transcript.isEmpty ? "Listening…" : transcript)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                HStack {
                    Button(action: onToggleMic) {
                        Image(systemName: isListening ? "mic.slash.fill" : "mic.fill")
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(isListening ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(isTyping || isSpeaking)
                    
                    Spacer()
                    
                    Button(role: .destructive, action: onCancelVoice) {
                        Image(systemName: "xmark")
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        } else {
            HStack(alignment: .bottom) {
                TextField("Talk to her...", text: $inputText, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        if isFocused {
                            isFocused = false
                        } else {
                            onEnterVoiceMode()
                        }
                    }) {
                        Image(systemName: isFocused ? "keyboard.chevron.compact.down" : "mic.fill")
                            .frame(width: 20, height: 20)
                            .padding(10)
                            .background(isFocused ? Color.gray.opacity(0.2) : Color.gray)
                            .foregroundColor(isFocused ? .primary : .white)
                            .clipShape(Circle())
                    }
                    .disabled(!isFocused && (isTyping || isSpeaking))
                } else {
                    Button(action: onSendText) {
                        Image(systemName: "paperplane.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(isTyping)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
