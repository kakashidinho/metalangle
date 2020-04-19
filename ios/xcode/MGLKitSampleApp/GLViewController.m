//
//  ViewController.m
//  MGLKitSampleApp
//
//  Created by Le Quyen on 15/10/19.
//  Created by Ray Wenderlich on 5/24/11.
//  Copyright © 2019 HQGame. All rights reserved.
//
//  See original tutorial:
//  https://www.raywenderlich.com/3047-opengl-es-2-0-for-iphone-tutorial-part-2-textures
//

#import "GLViewController.h"

#if TARGET_OS_OSX
// macOS emulation of UIImage
#    import <AppKit/NSImage.h>

typedef NSImage MGLKNativeImage;

@interface NSImage (MGLK)
- (CGImageRef)CGImage;
@end

@implementation NSImage (MGLK)
- (CGImageRef)CGImage
{
    CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
    return [self CGImageForProposedRect:&rect context:nil hints:nil];
}
@end

#else  // TARGET_OS_OSX
#    import <UIKit/UIImage.h>
#    import "PVRTexture.h"

typedef UIImage MGLKNativeImage;
#endif  // TARGET_OS_OSX

#include <MetalANGLE/GLES2/gl2.h>

#import "CC3GLMatrix.h"

@interface GLViewController () {
    GLuint _positionSlot;
    GLuint _colorSlot;
    GLuint _projectionUniform;
    GLuint _modelViewUniform;
    float _currentRotation;

    GLuint _programHandle;
    GLuint _floorTexture;
    GLuint _fishTexture;
    GLuint _texCoordSlot;
    GLuint _textureUniform;
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    GLuint _vertexBuffer2;
    GLuint _indexBuffer2;

    MGLContext *_asyncLoadContext;

    BOOL _resourceLoadFinish;
}

@end

@implementation GLViewController

typedef struct
{
    float Position[3];
    float Color[4];
    float TexCoord[2];  // New
} Vertex;

#define TEX_COORD_MAX 4

const Vertex Vertices[] = {
    // Front
    {{1, -1, 0}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{1, 1, 0}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{-1, 1, 0}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{-1, -1, 0}, {0, 0, 0, 1}, {0, 0}},
    // Back
    {{1, 1, -2}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{-1, -1, -2}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{1, -1, -2}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{-1, 1, -2}, {0, 0, 0, 1}, {0, 0}},
    // Left
    {{-1, -1, 0}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{-1, 1, 0}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{-1, 1, -2}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{-1, -1, -2}, {0, 0, 0, 1}, {0, 0}},
    // Right
    {{1, -1, -2}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{1, 1, -2}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{1, 1, 0}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{1, -1, 0}, {0, 0, 0, 1}, {0, 0}},
    // Top
    {{1, 1, 0}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{1, 1, -2}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{-1, 1, -2}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{-1, 1, 0}, {0, 0, 0, 1}, {0, 0}},
    // Bottom
    {{1, -1, -2}, {1, 0, 0, 1}, {TEX_COORD_MAX, 0}},
    {{1, -1, 0}, {0, 1, 0, 1}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{-1, -1, 0}, {0, 0, 1, 1}, {0, TEX_COORD_MAX}},
    {{-1, -1, -2}, {0, 0, 0, 1}, {0, 0}}};

const GLubyte Indices[] = {
    // Front
    0, 1, 2, 2, 3, 0,
    // Back
    4, 5, 6, 6, 7, 4,
    // Left
    8, 9, 10, 10, 11, 8,
    // Right
    12, 13, 14, 14, 15, 12,
    // Top
    16, 17, 18, 18, 19, 16,
    // Bottom
    20, 21, 22, 22, 23, 20};

const Vertex Vertices2[] = {
    {{0.5, -0.5, 0.01}, {1, 1, 1, 1}, {1, 1}},
    {{0.5, 0.5, 0.01}, {1, 1, 1, 1}, {1, 0}},
    {{-0.5, 0.5, 0.01}, {1, 1, 1, 1}, {0, 0}},
    {{-0.5, -0.5, 0.01}, {1, 1, 1, 1}, {0, 1}},
};

const GLubyte Indices2[] = {1, 0, 2, 3};

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.preferredFramesPerSecond = 60;

    // Create OpenGL context
    self.glView.drawableDepthFormat = MGLDrawableDepthFormat16;

    MGLContext *context = [[MGLContext alloc] initWithAPI:kMGLRenderingAPIOpenGLES2];
    self.glView.context = context;

    [MGLContext setCurrentContext:context];

    [self setupGL];
}

- (CGSize)size
{
    return self.glView.drawableSize;
}

- (GLuint)compileShader:(NSString *)shaderName withType:(GLenum)shaderType
{

    // 1
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"glsl"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    if (!shaderString)
    {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }

    // 2
    GLuint shaderHandle = glCreateShader(shaderType);

    // 3
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength       = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);

    // 4
    glCompileShader(shaderHandle);

    // 5
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }

    return shaderHandle;
}

- (void)compileShaders
{

    // 1
    GLuint vertexShader   = [self compileShader:@"SimpleVertex" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"SimpleFragment" withType:GL_FRAGMENT_SHADER];

    // 2
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);

    // 3
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }

    // 4
    glUseProgram(programHandle);
    _programHandle = programHandle;

    // 5
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot    = glGetAttribLocation(programHandle, "SourceColor");

    _projectionUniform = glGetUniformLocation(programHandle, "Projection");
    _modelViewUniform  = glGetUniformLocation(programHandle, "Modelview");

    _texCoordSlot = glGetAttribLocation(programHandle, "TexCoordIn");

    _textureUniform = glGetUniformLocation(programHandle, "Texture");
}

- (void)setupVBOs
{

    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);

    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);

    glGenBuffers(1, &_vertexBuffer2);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer2);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices2), Vertices2, GL_STATIC_DRAW);

    glGenBuffers(1, &_indexBuffer2);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer2);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices2), Indices2, GL_STATIC_DRAW);
}

- (GLuint)setupTexture:(NSString *)fileName
{

    // 1
    CGImageRef spriteImage = [MGLKNativeImage imageNamed:fileName].CGImage;
    if (!spriteImage)
    {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }

    // 2
    size_t width  = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);

    GLubyte *spriteData = (GLubyte *)calloc(width * height * 4, sizeof(GLubyte));

    CGContextRef spriteContext =
        CGBitmapContextCreate(spriteData, width, height, 8, width * 4,
                              CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);

    // 3
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);

    CGContextRelease(spriteContext);

    // 4
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE,
                 spriteData);

    free(spriteData);
    return texName;
}

- (void)loadResources
{
    [self compileShaders];
    [self setupVBOs];

#if TARGET_OS_IOS || TARGET_OS_TV
    if (strstr((const char *)glGetString(GL_EXTENSIONS), "IMG_texture_compression_pvrtc"))
    {
        _floorTexture = [PVRTexture glTextureWithContentsOfFile:@"tile_floor.pvr"];
        _fishTexture  = [PVRTexture glTextureWithContentsOfFile:@"item_powerup_fish.pvr"];
    }
    else
#endif
    {
        _floorTexture = [self setupTexture:@"tile_floor.png"];
        _fishTexture  = [self setupTexture:@"item_powerup_fish.png"];
    }
}

- (void)setupGL
{
    if (!getenv("MGL_SAMPLE_ASYNC_RESOURCE_LOAD"))
    {
        // Immediate resource loading.
        [self loadResources];
        _resourceLoadFinish = YES;
    }
    else
    {
        // Do asynchronous resource loading
        _asyncLoadContext = [[MGLContext alloc] initWithAPI:kMGLRenderingAPIOpenGLES2 sharegroup:self.glView.context.sharegroup];
        __auto_type bgQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
        dispatch_async(bgQueue, ^{
            [MGLContext setCurrentContext:self->_asyncLoadContext];
            [self loadResources];

            glFlush();

            dispatch_async(dispatch_get_main_queue(), ^{
                self->_resourceLoadFinish = YES;
            });
        });
    }
}

- (void)update
{}

- (void)mglkView:(MGLKView *)view drawInRect:(CGRect)rect
{
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    glClearColor(0, 104.0 / 255.0, 55.0 / 255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    if (!_resourceLoadFinish)
    {
        return;
    }

    glUseProgram(_programHandle);

    CC3GLMatrix *projection = [CC3GLMatrix matrix];
    float h                 = 4.0f * self.size.height / self.size.width;
    [projection populateFromFrustumLeft:-2
                               andRight:2
                              andBottom:-h / 2
                                 andTop:h / 2
                                andNear:4
                                 andFar:10];
    glUniformMatrix4fv(_projectionUniform, 1, 0, projection.glMatrix);

    CC3GLMatrix *modelView = [CC3GLMatrix matrix];
    [modelView populateFromTranslation:CC3VectorMake(sin(CACurrentMediaTime()), 0, -7)];
    _currentRotation += self.timeSinceLastUpdate * 90;
    [modelView rotateBy:CC3VectorMake(_currentRotation, _currentRotation, 0)];
    glUniformMatrix4fv(_modelViewUniform, 1, 0, modelView.glMatrix);

    // 1
    glViewport(0, 0, self.size.width, self.size.height);

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);

    // 2
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                          (GLvoid *)(sizeof(float) * 3));

    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                          (GLvoid *)(sizeof(float) * 7));

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _floorTexture);
    glUniform1i(_textureUniform, 0);

    // 3
    glDrawElements(GL_TRIANGLES, sizeof(Indices) / sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer2);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer2);

    glActiveTexture(GL_TEXTURE0);  // unneccc in practice
    glBindTexture(GL_TEXTURE_2D, _fishTexture);
    glUniform1i(_textureUniform, 0);  // unnecc in practice

    glUniformMatrix4fv(_modelViewUniform, 1, 0, modelView.glMatrix);

    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    glEnableVertexAttribArray(_texCoordSlot);

    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                          (GLvoid *)(sizeof(float) * 3));
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                          (GLvoid *)(sizeof(float) * 7));

    glDrawElements(GL_TRIANGLE_STRIP, sizeof(Indices2) / sizeof(Indices2[0]), GL_UNSIGNED_BYTE, 0);
}

@end
