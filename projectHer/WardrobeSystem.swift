// WardrobeSystem.swift - Clothing management

import Foundation
import Combine

enum ClothingCategory: String, Codable, CaseIterable {
    case top
    case bottom
    case dress
    case outerwear
    case sleepwear
    case swimwear
    case accessories
    case footwear
}

enum ClothingStyle: String, Codable {
    case casual
    case formal
    case sporty
    case cozy
    case elegant
    case cute
    case sexy
    case professional
    case festive
}

struct ClothingItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: ClothingCategory
    let style: ClothingStyle
    let color: String
    let description: String
    let appropriateFor: [String] // locations/occasions
    let weatherSuitability: [String] // cold, warm, rain, etc
    let modelAsset: String // The actual asset name in Assets.xcassets
    
    // Mapped from AvatarView.swift assets
    static let defaultWardrobe: [ClothingItem] = [
        // -- Dresses / Full Body --
        ClothingItem(id: "orange_simple", name: "Orange Simple Dress", category: .dress, style: .casual,
                     color: "orange", description: "Simple orange daily dress",
                     appropriateFor: ["home", "casual", "cafe"],
                     weatherSuitability: ["warm", "cool"], modelAsset: "avatar_outfit_orange_simple"),
        
        ClothingItem(id: "red_bikini", name: "Red Bikini", category: .swimwear, style: .sexy,
                     color: "red", description: "Red bikini for swimming",
                     appropriateFor: ["beach", "pool"],
                     weatherSuitability: ["hot"], modelAsset: "avatar_outfit_bikini_red"),
        
        ClothingItem(id: "gold_camisole", name: "Gold Camisole", category: .top, style: .elegant,
                     color: "gold", description: "Elegant gold camisole top",
                     appropriateFor: ["party", "date"],
                     weatherSuitability: ["warm", "indoor"], modelAsset: "avatar_outfit_camisole_gold"),
        
        ClothingItem(id: "festive_red", name: "Festive Red Outfit", category: .dress, style: .festive,
                     color: "red", description: "Red festive outfit for holidays",
                     appropriateFor: ["holiday", "party"],
                     weatherSuitability: ["cool", "cold"], modelAsset: "avatar_outfit_festive"),
        
        ClothingItem(id: "festive_green", name: "Festive Green Outfit", category: .dress, style: .festive,
                     color: "green", description: "Green festive outfit",
                     appropriateFor: ["holiday", "party"],
                     weatherSuitability: ["cool", "cold"], modelAsset: "avatar_outfit_festive_2"),
        
        ClothingItem(id: "hoodie_black", name: "Black Hoodie", category: .top, style: .casual,
                     color: "black", description: "Comfy black hoodie",
                     appropriateFor: ["home", "casual", "street"],
                     weatherSuitability: ["cool", "cold"], modelAsset: "avatar_outfit_hoodie_black"),
        
        ClothingItem(id: "purple_fancy", name: "Purple Fancy Dress", category: .dress, style: .elegant,
                     color: "purple", description: "Fancy purple dress for events",
                     appropriateFor: ["formal", "date", "party"],
                     weatherSuitability: ["cool", "warm"], modelAsset: "avatar_outfit_purple_fancy"),
        
        ClothingItem(id: "cableknit", name: "Cableknit Sweater", category: .top, style: .cozy,
                     color: "white", description: "Warm cableknit sweater",
                     appropriateFor: ["home", "casual", "winter"],
                     weatherSuitability: ["cold"], modelAsset: "avatar_outfit_sweater_cableknit"),
        
        ClothingItem(id: "sweatshirt_blue", name: "Blue Sweatshirt", category: .top, style: .sporty,
                     color: "blue", description: "Casual blue sweatshirt",
                     appropriateFor: ["casual", "gym", "home"],
                     weatherSuitability: ["cool"], modelAsset: "avatar_outfit_sweatshirt_blue"),
        
        ClothingItem(id: "vest_brown", name: "Brown Vest", category: .outerwear, style: .casual,
                     color: "brown", description: "Brown utility vest",
                     appropriateFor: ["outdoor", "casual"],
                     weatherSuitability: ["cool"], modelAsset: "avatar_outfit_vest_brown"),
        
        // -- Accessories --
        
        ClothingItem(id: "scarf", name: "Winter Scarf", category: .accessories, style: .cozy,
                     color: "red", description: "Warm red scarf",
                     appropriateFor: ["outdoor", "cold"],
                     weatherSuitability: ["cold", "wind"], modelAsset: "scarf"),
                     
        ClothingItem(id: "pendant", name: "Pendant", category: .accessories, style: .elegant,
                     color: "gold", description: "Simple gold necklace",
                     appropriateFor: ["any"],
                     weatherSuitability: ["any"], modelAsset: "pendant")
    ]
}

struct CurrentOutfit: Codable {
    var base: ClothingItem // Since most are full body sprites, we use 'base'
    var accessories: [ClothingItem]
    
    var description: String {
        var parts: [String] = [base.name]
        if !accessories.isEmpty {
            parts.append(contentsOf: accessories.map { $0.name })
        }
        return parts.joined(separator: " with ")
    }
    
    func toModelContext() -> String {
        return """
        [CURRENT OUTFIT]
        \(description)
        Style: \(base.style.rawValue)
        """
    }
}

 @MainActor
class WardrobeManager: ObservableObject {
    static let shared = WardrobeManager()
    
    @Published var wardrobe: [ClothingItem] = ClothingItem.defaultWardrobe
    
    // Default to Orange Simple + No Accessories
    @Published var currentOutfit: CurrentOutfit = CurrentOutfit(
        base: ClothingItem.defaultWardrobe.first(where: { $0.id == "orange_simple" })!,
        accessories: []
    )
    
    @Published var isChanging: Bool = false
    
    private init() {
        loadSavedOutfit()
    }
    
    // MARK: - Outfit Selection
    
    func changeOutfit(to item: ClothingItem) {
        if item.category == .accessories {
            // Toggle accessory
            if currentOutfit.accessories.contains(where: { $0.id == item.id }) {
                currentOutfit.accessories.removeAll(where: { $0.id == item.id })
            } else {
                // Remove conflicting accessories if needed (e.g. only 1 hat)
                if item.id.contains("hat") {
                    currentOutfit.accessories.removeAll(where: { $0.id.contains("hat") })
                }
                currentOutfit.accessories.append(item)
            }
        } else {
            // Change base outfit
            currentOutfit.base = item
        }
        saveOutfit()
    }
    
    // MARK: - Persistence
    
    private func saveOutfit() {
        if let data = try? JSONEncoder().encode(currentOutfit) {
            UserDefaults.standard.set(data, forKey: "projectHer_current_outfit")
        }
    }
    
    private func loadSavedOutfit() {
        if let data = UserDefaults.standard.data(forKey: "projectHer_current_outfit"),
           let outfit = try? JSONDecoder().decode(CurrentOutfit.self, from: data) {
            currentOutfit = outfit
        }
    }
}
