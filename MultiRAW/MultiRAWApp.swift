//
//  MultiRAWApp.swift
//  MultiRAW
//
//  Created by Andrew Pouliot on 8/1/20.
//

import SwiftUI

@main
struct MultiRAWApp: App {
    var body: some Scene {
        WindowGroup {
            CaptureView()
                .colorScheme(.dark)
        }
    }
}
