import SwiftUI

struct CustomProgressView: View {
    var progress: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color(.systemGray5))
                    .cornerRadius(5)
                
                Rectangle()
                    .foregroundColor(color)
                    .frame(width: CGFloat(progress) * geometry.size.width)
                    .cornerRadius(5)
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
    }
}

struct CustomProgressView_Previews: PreviewProvider {
    static var previews: some View {
        CustomProgressView(progress: 0.7, color: .blue)
            .frame(height: 10)
            .padding()
    }
}
