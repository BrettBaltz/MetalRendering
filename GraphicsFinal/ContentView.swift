import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView().frame(minWidth: 600, maxWidth: 800, minHeight: 600, maxHeight: 800)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

