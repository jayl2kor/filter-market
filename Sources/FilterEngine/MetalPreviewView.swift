import MetalKit
import SwiftUI

public struct MetalPreviewView: UIViewRepresentable {
    private let renderer: MetalPreviewRenderer

    public init(renderer: MetalPreviewRenderer) {
        self.renderer = renderer
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        renderer.configure(view)
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}
}
