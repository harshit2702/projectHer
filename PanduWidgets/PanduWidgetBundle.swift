//
//  PanduWidgetBundle.swift
//  PanduWidgets
//
//  Widget Extension for projectHer
//  Displays mood, location, and current activity
//

import WidgetKit
import SwiftUI

@main
struct PanduWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        // Home Screen Widgets (always available)
        PanduStatusWidget()
        PanduMoodWidget()
        
        // Live Activities (iOS 16.1+)
        if #available(iOSApplicationExtension 16.1, *) {
            PanduTransitLiveActivity()
            PanduSleepLiveActivity()
        }
    }
}

