//
//  RepRankWidgetBundle.swift
//  RepRankWidget
//
//  Created by 酒井勇太 on 2026/09/01.
//

import WidgetKit
import SwiftUI

@main
struct RepRankWidgetBundle: WidgetBundle {
    var body: some Widget {
        RepRankWidget()
        RepRankWidgetControl()
        RepRankWidgetLiveActivity()
    }
}
