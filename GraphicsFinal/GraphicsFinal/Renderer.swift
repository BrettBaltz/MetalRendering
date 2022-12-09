import Foundation
import MetalKit
import simd

let textureFiles = ["mini_body_diffuse.png", "mini_body_spec.png",
                    "mini_brakes_diffuse.png", "mini_parts_diffuse.png",
                    "mini_parts_spec.png", "mini_rims_diffuse.png",
                    "mini_tires_diffuse.png", "mini-flags.png"]

class Renderer: NSObject, MTKViewDelegate {
    let parent: MetalView
    var metalDevice: MTLDevice!
    let metalCommandQueue: MTLCommandQueue!
    let depthStencilState: MTLDepthStencilState
    let pipelineState: MTLRenderPipelineState
    let geometry: Geometry
    var materials: [String: Material] = [:]
    var vertexUniforms: VertexUniforms
    var fragmentUniforms: FragmentUniforms
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let uniformVertexBuffer: MTLBuffer
    let uniformFragmentBuffer: MTLBuffer
    var textures: [String: MTLTexture] = [:]
    
    init(_ parent: MetalView) {
        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        self.metalCommandQueue = metalDevice.makeCommandQueue()
        let library = metalDevice.makeDefaultLibrary()
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(
            name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(
            name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Set the vertex attribute array
        let vertexDescriptor = MTLVertexDescriptor()
        let SIZE_FLOAT3 = MemoryLayout<simd_float3>.stride
        vertexDescriptor.attributes[0].format = .float3          // Position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3          // Normal
        vertexDescriptor.attributes[1].offset = SIZE_FLOAT3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float2          // Tex coord
        vertexDescriptor.attributes[2].offset = SIZE_FLOAT3 * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
    
        try! pipelineState = metalDevice.makeRenderPipelineState(
            descriptor: pipelineDescriptor)
        
        // Set the DepthStencilDescriptor so that primvitives are rendered
        // according to z value instead of the painter's algorithm
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = metalDevice.makeDepthStencilState(
            descriptor: depthStencilDescriptor)!
        
        // Read geometry data from file
        var path = Bundle.main.path(
            forResource: "mini_geometry",
            ofType: "json"
        )!
        var data = FileManager().contents(atPath: path)!
        try! geometry = JSONDecoder().decode(Geometry.self, from: data)
        
        // Read materials data from file
        path = Bundle.main.path(forResource: "mini_material", ofType: "json")!
        data = FileManager().contents(atPath: path)!
        try! materials = JSONDecoder().decode(
            Dictionary<String, Material>.self,
            from: data
        )
        
        // Create vertices based on structure of vertexdata
        var vertices: [Vertex] = []
        for i in stride(from: 0, to: geometry.vertexdata.count, by: 8) {
            let vertex = Vertex(
                position: simd_float3(geometry.vertexdata[i ... i + 2]),
                normal: simd_float3(geometry.vertexdata[i + 3 ... i + 5]),
                texCoord: simd_float2(geometry.vertexdata[i + 6 ... i + 7])
            )
            vertices.append(vertex)
        }
        
        // Define matrices for transforming positions from local coordinates
        // to world coordinates
        var modelMatrix = createIdentityMatrix()
        modelMatrix = rotateByX(mat: modelMatrix, rad: toRad(-60))
        modelMatrix = rotateByY(mat: modelMatrix, rad: Float.pi)
        let viewMatrix = lookAt(
            eye: simd_float3(0, 0, 1),
            center: simd_float3(0, 0, 0),
            up: simd_float3(0, 1, 0)
        )
        let projectionMatrix = ortho(
            left:   -200, right: 200,
            bottom: -200, top:   200,
            near:   -200, far:   200
        )
        
        // Store matrices as uniforms for access by the vertex shader
        vertexUniforms = VertexUniforms(
            modelMatrix: modelMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix
        )
        // Store values for access by the fragment shader. These will be
        // changed in draw
        fragmentUniforms = FragmentUniforms(
            color: simd_float3(0.0, 0.0, 0.0),
            hasDiffuseTexture: false,
            hasSpecularTexture: false
        )
        
        vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: []
        )!
        indexBuffer = metalDevice.makeBuffer(
            bytes: geometry.indexdata,
            length: geometry.indexdata.count * MemoryLayout<UInt16>.stride,
            options: []
        )!
        uniformVertexBuffer = metalDevice.makeBuffer(
            bytes: &vertexUniforms,
            length: MemoryLayout<VertexUniforms>.stride,
            options: []
        )!
        uniformFragmentBuffer = metalDevice.makeBuffer(
            bytes: &fragmentUniforms,
            length: MemoryLayout<FragmentUniforms>.stride,
            options: []
        )!
        

        
        super.init()
        
        // Configure options on how to load the texture
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.flippedVertically,
            .generateMipmaps: true
        ]
        
        // Load each texture and store in a dictionary for reference in draw
        textures = [:]
        for i in stride(from: 0, to: textureFiles.count, by: 1) {
            let dir = "textures/"
            let newTexture = loadTexture(filename: dir + textureFiles[i],
                                         options: textureOptions)
            textures[textureFiles[i]] = newTexture
        }
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable
        else { return }
        
        let commandBuffer = metalCommandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor =
            MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor)!
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.setVertexBuffer(
            vertexBuffer,
            offset: 0,
            index: 0
        )
        renderEncoder.setVertexBuffer(
            uniformVertexBuffer,
            offset: 0,
            index: 1
        )
        renderEncoder.setFragmentBuffer(
            uniformFragmentBuffer,
            offset: 0,
            index: 0
        )
        
        // Continuously rotate the car a small amount
        vertexUniforms.modelMatrix = rotateByZ(
            mat: vertexUniforms.modelMatrix,
            rad: toRad(0.25)
        )
        uniformVertexBuffer.contents().copyMemory(
            from: &vertexUniforms,
            byteCount: MemoryLayout<VertexUniforms>.stride
        )
        
        for (part, indices) in geometry.groups {
            if (materials[part]?.diffuse) != "" {
                fragmentUniforms.hasDiffuseTexture = true
                renderEncoder.setFragmentTexture(
                    textures[(materials[part]?.diffuse)!],
                    index: 0
                )
            }
            else {
                fragmentUniforms.hasDiffuseTexture = false
                renderEncoder.setFragmentTexture(nil, index: 0)
            }
            if (materials[part]?.specular) != "" {
                fragmentUniforms.hasSpecularTexture = true
                renderEncoder.setFragmentTexture(
                    textures[(materials[part]?.specular)!],
                    index: 1
                )
            }
            else {
                fragmentUniforms.hasSpecularTexture = false
                renderEncoder.setFragmentTexture(nil, index: 1)
            }
            
            // Copy new color to memory for access by the fragment shader
            fragmentUniforms.color = (materials[part]?.color)!
            uniformFragmentBuffer.contents().copyMemory(
                from: &fragmentUniforms,
                byteCount: MemoryLayout<FragmentUniforms>.stride
            )
            
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: (indices[1] - indices[0]) * 3,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: indices[0] * 3 * MemoryLayout<UInt16>.stride
            )
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func loadTexture(filename: String,
                     options: [MTKTextureLoader.Option : Any])
    -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: metalDevice)
        let url = Bundle.main.url(forResource: filename, withExtension: nil)!
        
        let newTexture: MTLTexture
        try! newTexture = textureLoader.newTexture(URL: url, options: options)
        return newTexture
    }
}

