//
//  GLViewController.swift
//  MGLKitSampleSwiftApp
//
//  Created by Le Quyen on 7/5/21.
//  Copyright © 2021 HQGame. All rights reserved.
//

class GLViewController: MGLKViewController {

    var _glProgram : GLuint = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        let glContext = MGLContext(api: kMGLRenderingAPIOpenGLES3)
        self.glView?.context = glContext

        MGLContext.setCurrent(glContext)

        initGL()
    }

    override func mglkView(_ view: MGLKView!, drawIn rect: CGRect) {
        let vertices : ContiguousArray<Float> = [
            0.0, 0.5, 0.0, -0.5, -0.5, 0.0, 0.5, -0.5, 0.0,
        ]

        // Set the viewport
        let viewSize = self.glView?.drawableSize
        glViewport(0, 0, GLsizei(viewSize?.width ?? 0), GLsizei(viewSize?.height ?? 0))

        // Clear the color buffer
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        // Use the program object
        glUseProgram(_glProgram)

        // Load the vertex data
        vertices.withUnsafeBufferPointer{ (verticesBuf) -> Void in
            glVertexAttribPointer(0, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, verticesBuf.baseAddress)
        }
        glEnableVertexAttribArray(0)

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    private func initGL() {
        let vs = """
        attribute vec4 vPosition;
        void main()
        {
            gl_Position = vPosition;
        }
        """

        let fs = """
        precision mediump float;
        void main()
        {
            gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
        }
        """

        _glProgram = compileShaders(vs: vs, fs: fs)
    }

    private func compileShaders(vs: String, fs: String) -> GLuint {
        let vertexShader   = compileShader(source: vs, shaderType: GLenum(GL_VERTEX_SHADER))
        let fragmentShader = compileShader(source: fs, shaderType: GLenum(GL_FRAGMENT_SHADER))

        let programHandle = glCreateProgram()
        glAttachShader(programHandle, vertexShader)
        glAttachShader(programHandle, fragmentShader)

        glLinkProgram(programHandle);

        var linkSuccess : GLint = 0;
        glGetProgramiv(programHandle, GLenum(GL_LINK_STATUS), &linkSuccess);
        if (linkSuccess == GL_FALSE)
        {
            let cMessage = UnsafeMutableBufferPointer<CChar>.allocate(capacity: 256)
            glGetProgramInfoLog(programHandle, 256, nil, cMessage.baseAddress!)
            let message = String(cString: cMessage.baseAddress!)
            NSLog("%@", message)
            exit(1)
        }

        return programHandle;
    }

    private func compileShader(source: String, shaderType: GLenum) -> GLuint {
        let shaderHandle = glCreateShader(shaderType)

        let shaderStringUTF8 = source.utf8CString
        var shaderStringLength = GLint(shaderStringUTF8.count);

        shaderStringUTF8.withUnsafeBufferPointer{ (shaderStringBufPtr) -> Void in
            var shaderStringCPtr = shaderStringBufPtr.baseAddress
            glShaderSource(shaderHandle, 1, &shaderStringCPtr, &shaderStringLength)
        }

        glCompileShader(shaderHandle)

        var compileSuccess : GLint = 0;
        glGetShaderiv(shaderHandle, GLenum(GL_COMPILE_STATUS), &compileSuccess);
        if (compileSuccess == GL_FALSE)
        {
            let cMessage = UnsafeMutableBufferPointer<CChar>.allocate(capacity: 256)
            glGetShaderInfoLog(shaderHandle, 256, nil, cMessage.baseAddress!)
            let message = String(cString: cMessage.baseAddress!)
            NSLog("%@", message)
            exit(1)
        }

        return shaderHandle;
    }
}

