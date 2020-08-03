import SwiftUI
import AVFoundation

struct CaptureView: View {
    // does the actual capture logic
    @ObservedObject var capture = CaptureController()
    
    func showReview() {
        showingReview = true
    }
    
    @State var showingReview = false
    
    var body: some View {
        NavigationView {
            VStack{
                PreviewView(captureSession: $capture.captureSession)
                    .onAppear(perform: capture.start)
                    .onDisappear(perform: capture.stop)
                    .background(Color.black)
                    .edgesIgnoringSafeArea([.top])
                CaptureControls(capturing: $capture.capturing, recentCapture: $capture.recentCapture,
                                capture: capture.capture,
                                showSettings: {},
                                showReview: showReview)
                NavigationLink(
                    destination: HStack{
                        if let recentCapture = $capture.recentCapture.wrappedValue {
                            Review(image: recentCapture)
                        }
                    },
                    isActive: $showingReview){
                }
            }
        }
    }
}

struct CaptureControls: View {
    
    @Binding var capturing: Bool
    @Binding var recentCapture: CaptureImage?
    
    let capture: () -> ()
    let showSettings: () -> ()
    let showReview: () -> ()

    var body: some View {
        HStack(alignment: .center) {
            if let recentCapture = recentCapture, let previewImage = recentCapture.previewImage {
                Button(action: showReview) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .background(Color.orange)
                        .cornerRadius(3.0)
                        .frame(width: 45.0, height: 45.0)
                }.buttonStyle(PlainButtonStyle()) // Plain style allows the image to show colors

            } else {
                Button(action: showReview) {
                    Image(systemName: "photo")
                        .frame(width: 45.0, height: 45.0)
                        .imageScale(.large)
                        .background(Color.gray)
                        .cornerRadius(3.0)
                }
            }
            Button(action: capture) {
                Circle()
                    .inset(by: 8)
                    .stroke(lineWidth: 4)
                    .background(
                        Circle().inset(by: 12)
                            .fill(capturing ? Color.secondary : Color.white)
                    )
            }
            .disabled(capturing)
            Button(action: showSettings) {
                Image(systemName: "gearshape.fill")
                    .frame(width: 45.0, height: 45.0)
                    .imageScale(.large)
            }
        }
        .padding(.horizontal)
        .background(Color.black)
        .frame(height: 100.0)
    }
}

struct CaptureControls_Previews: PreviewProvider {
    static var previews: some View {
        CaptureControls(
            capturing: Binding.constant(false),
            recentCapture: Binding.constant(nil),
            capture: {},
            showSettings: {},
            showReview: {})
            .colorScheme(.light)
            .previewLayout(.fixed(width: 400, height: 100))
        
        CaptureControls(
            capturing: Binding.constant(true),
            recentCapture: Binding.constant(nil),
            capture: {},
            showSettings: {},
            showReview: {})
            .colorScheme(.light)
            .previewLayout(.fixed(width: 400, height: 100))

        CaptureControls(
            capturing: Binding.constant(false),
            recentCapture: Binding.constant(CaptureImage(id: 123, expected: 1, previewImage: UIImage(named: "captured")!, images: [])),
            capture: {},
            showSettings: {},
            showReview: {})
            .colorScheme(.light)
            .previewLayout(.fixed(width: 400, height: 100))

        CaptureView(capture: CaptureController(), showingReview: false)

    }
}

