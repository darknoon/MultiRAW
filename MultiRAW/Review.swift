import SwiftUI
import AVFoundation

// MARK: Define input data

protocol ReviewableImage {
    var metadata: [String : Any] { get }
    var uiImage: UIImage? { get }
}

protocol Reviewable {
    associatedtype RImage: Identifiable, ReviewableImage
    var images: [RImage] { get }
}

// MARK: Review View

struct ReviewItem<T : ReviewableImage>: View {
    
    let image: T
    
    var body: some View {
        if let im = image.uiImage {
            Image(uiImage: im)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .cornerRadius(3)
                .padding(3)

        } else {
            Text("No image")
                .frame(width: 45.0, height: 45.0)
        }
    }
}

struct Review<T : Reviewable>: View {
    
    var image: T
    
    var body: some View {
        let columns: [GridItem] =
                Array(repeating: .init(.flexible()), count: 2)
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(image.images) { im in
                    ReviewItem<T.RImage>(image: im)
                }
            }
        }
    }
}

// MARK: Allow captured photo to be reviewable

extension CaptureImage : Reviewable {
    typealias RImage = AVCapturePhoto
}

extension AVCapturePhoto : ReviewableImage {
    
    var uiImage: UIImage? {
        guard let cgim = self.cgImageRepresentation()?.takeUnretainedValue() else { return nil }
        return UIImage(cgImage: cgim, scale: 1.0, orientation: UIImage.Orientation.up)
    }
    
}

extension AVCapturePhoto: Identifiable {
    public var id: Int {
        return photoCount
    }
}

// MARK: Mock photo for previews


struct _Preview_Reviewable : Reviewable {
    typealias RImage = _Preview_Reviewable_Image
    var images: [_Preview_Reviewable_Image] = Array(repeating: _Preview_Reviewable_Image(), count: 4)
}

struct _Preview_Reviewable_Image : ReviewableImage, Identifiable {
    var id: UUID = UUID()
    var metadata: [String : Any] = [:]
    
    var uiImage: UIImage? = UIImage(named: "captured")
}

// MARK: SwiftUI Previews

struct Review_Previews: PreviewProvider {
    static var previews: some View {
        ReviewItem(image: _Preview_Reviewable_Image())
            .colorScheme(.dark)
            .previewLayout(.fixed(width: 150, height: 200))

        Review(image: _Preview_Reviewable())
    }
}
