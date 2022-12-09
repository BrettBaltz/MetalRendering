import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer { Renderer(self) }
    
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.drawableSize = mtkView.frame.size
        mtkView.isPaused = false
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {}
}

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
