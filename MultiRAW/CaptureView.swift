//  Created by Andrew Pouliot on 8/1/20.

import SwiftUI
import AVFoundation

struct CaptureView: View {
    // does the actual capture logic
    @ObservedObject var capture = Capture()
    
    var body: some View {
        NavigationView {
            VStack{
                PreviewView(captureSession: $capture.captureSession)
                    .onAppear(perform: capture.start)
                    .onDisappear(perform: capture.stop)
                    .background(Color.gray)
                    .edgesIgnoringSafeArea([.top])
                CaptureButton(capturing: $capture.capturing, capture: capture.capture)
            }
        }.colorScheme(.dark)

    }
}

struct CaptureButton: View {
    
    @Binding var capturing: Bool
    
    let capture: () -> ()
    
    var body: some View {
        HStack {
            Button(action: capture) {
                Circle()
                    .inset(by: 8)
                    .stroke(capturing  ? Color.yellow : Color.white, lineWidth: 4)
            }.disabled(capturing)
        }
        .background(Color.black)
        .frame(height: 100.0)
    }
}

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureView()
            .previewDevice("iPhone 11")
            .colorScheme(.dark)
    }
}

