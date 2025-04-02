import SwiftUI

// Renamed to VideoProgressBar to avoid naming conflict
struct VideoProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: 10)
                    .opacity(0.1)
                    .foregroundColor(color)
                    .cornerRadius(5)
                
                Rectangle()
                    .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 10)
                    .foregroundColor(color)
                    .cornerRadius(5)
                    .animation(.linear, value: progress)
            }
        }
        .frame(height: 10)
    }
}