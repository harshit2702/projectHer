import SwiftUI

enum ConnectionStatus {
    case connected
    case disconnected
    case slow
    case authError
    case serverError
    case checking
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .slow: return .yellow
        case .disconnected, .authError, .serverError: return .red
        case .checking: return .gray
        }
    }
    
    var message: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Can't reach server - Is your Mac on?"
        case .slow: return "Network slow"
        case .authError: return "Authentication failed - Check API key"
        case .serverError: return "Server error"
        case .checking: return "Checking connection..."
        }
    }
}
