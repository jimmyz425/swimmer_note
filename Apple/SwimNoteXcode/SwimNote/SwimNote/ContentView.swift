//
//  ContentView.swift
//  SwimNote
//
//  Created by jimmy zhong on 2026/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var appModel = SwimNoteAppModel.bootstrap()

    var body: some View {
        RootView(appModel: appModel)
            .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
