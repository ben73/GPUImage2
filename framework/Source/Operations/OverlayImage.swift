//
//  OverlayImage.swift
//  GPUImage
//
//  Created by ben on 25.08.17.
//  Copyright © 2017 Sunset Lake Software LLC. All rights reserved.
//
#if GLES
    import OpenGLES
#else
    import OpenGL.GL3
#endif

public class OverlayImage: BasicOperation {
    var overlayShader: ShaderProgram!
    var overlayUniformSettings = ShaderUniformSettings()
    var pictureInput: PictureInput!
    
    public var transformMatrix: Matrix4x4 = .identity {
        didSet {
            overlayUniformSettings["transformMatrix"] = transformMatrix
        }
    }
    
    public init(pictureInput: PictureInput) {
        super.init(vertexShader: nil, fragmentShader: PassthroughFragmentShader, numberOfInputs: 1)
        self.pictureInput = pictureInput
        ({ transformMatrix = .identity})()
        
        overlayShader = crashOnShaderCompileFailure(#file){try sharedImageProcessingContext.programForVertexShader(TransformVertexShader, fragmentShader:PassthroughFragmentShader)}
    }
    
    override func internalRenderFunction(_ inputFramebuffer: Framebuffer, textureProperties: [InputTextureProperties]) {
        renderQuadWithShader(shader, uniformSettings:uniformSettings, vertexBufferObject:sharedImageProcessingContext.standardImageVBO, inputTextures:textureProperties)
        renderImage()
        
        releaseIncomingFramebuffers()
    }
    
    override func configureFramebufferSpecificUniforms(_ inputFramebuffer:Framebuffer) {
        super.configureFramebufferSpecificUniforms(inputFramebuffer)
        let outputRotation = overriddenOutputRotation ?? inputFramebuffer.orientation.rotationNeededForOrientation(.portrait)
        let aspectRatio = inputFramebuffer.aspectRatioForRotation(outputRotation)
        let orthoMatrix = orthographicMatrix(-1.0, right:1.0, bottom:-1.0 * aspectRatio, top:1.0 * aspectRatio, near:-1.0, far:1.0)
        overlayUniformSettings["orthographicMatrix"] = orthoMatrix
    }
    
    private func renderImage() {
        let renderSize = inputFramebuffers[0]!.size
        let w = GLfloat(2.0) / GLfloat(renderSize.width)
        let h = GLfloat(2.0) / GLfloat(renderSize.height)
        let overlaySize = pictureInput.imageFramebuffer.size
        
        let nw: GLfloat = w * GLfloat(overlaySize.width) / GLfloat(2.0)
        let nh: GLfloat = h * GLfloat(overlaySize.height) / GLfloat(2.0) * (GLfloat(renderSize.height) / GLfloat(renderSize.width))
        
        let overlayVertices: [GLfloat] = [
            -nw, -nh,
            +nw, -nh,
            -nw, nh,
            nw, nh
        ]
        renderFramebuffer.activateFramebufferForRendering()
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA));
        glEnable(GLenum(GL_BLEND))
        renderQuadWithShader(overlayShader, uniformSettings:overlayUniformSettings, vertices:overlayVertices, inputTextures:[pictureInput.imageFramebuffer.texturePropertiesForOutputRotation(.noRotation)])
        glDisable(GLenum(GL_BLEND))
    }
    
}
