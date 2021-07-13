//
// Copyright 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ImageTestMetal:
//   Tests the correctness of eglImage with native Metal texture extensions.
//

#include "test_utils/ANGLETest.h"

#include "common/mathutil.h"
#include "test_utils/gl_raii.h"
#include "util/EGLWindow.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Metal/Metal.h>

namespace angle
{
namespace
{
constexpr char kOESExt[]                      = "GL_OES_EGL_image";
constexpr char kBaseExt[]                     = "EGL_KHR_image_base";
constexpr char kDeviceMtlExt[]                = "EGL_ANGLE_device_mtl";
constexpr char kEGLImageCubeExt[]             = "GL_MGL_EGL_image_cube";
constexpr char kEGLMtlImageNativeTextureExt[] = "EGL_MGL_mtl_texture_client_buffer";
constexpr char kSemaphoreExt[]                = "GL_EXT_semaphore";
constexpr char kSemaphoreFdExt[]              = "GL_EXT_semaphore_fd";
constexpr char kSemaphoreTimelineExt[]        = "GL_MGL_timeline_semaphore";
constexpr EGLint kDefaultAttribs[]            = {
    EGL_NONE,
};
}  // anonymous namespace

template <typename T>
class ScopedMetalRef : angle::NonCopyable
{
  public:
    ScopedMetalRef() = default;
    explicit ScopedMetalRef(T ref) : mMetalRef(ref) {}

    ~ScopedMetalRef()
    {
        if (mMetalRef)
        {
            release();
            mMetalRef = nullptr;
        }
    }

    T get() const { return mMetalRef; }

    // auto cast to MTLTexture
    operator T() const { return mMetalRef; }
    ScopedMetalRef(const ScopedMetalRef &other)
    {
        if (mMetalRef)
        {
            release();
        }
        mMetalRef = other.mMetalRef;
    }

    explicit ScopedMetalRef(ScopedMetalRef &&other)
    {
        if (mMetalRef)
        {
            release();
        }
        mMetalRef       = other.mMetalRef;
        other.mMetalRef = nil;
    }

    ScopedMetalRef &operator=(ScopedMetalRef &&other)
    {
        if (mMetalRef)
        {
            release();
        }
        mMetalRef       = other.mMetalRef;
        other.mMetalRef = nil;

        return *this;
    }

    ScopedMetalRef &operator=(const ScopedMetalRef &other)
    {
        if (mMetalRef)
        {
            release();
        }
        mMetalRef = other.mMetalRef;
#if !__has_feature(objc_arc)
        [mMetalRef retain];
#endif

        return *this;
    }

  private:
    void release()
    {
#if !__has_feature(objc_arc)
        [mMetalRef release];
#endif
    }

    T mMetalRef = nil;
};

using ScopedMetalTextureRef     = ScopedMetalRef<id<MTLTexture>>;
using ScopedMetalSharedEventRef = ScopedMetalRef<id<MTLSharedEvent>>;

ScopedMetalTextureRef CreateMetalTexture2D(id<MTLDevice> deviceMtl,
                                           int width,
                                           int height,
                                           MTLPixelFormat format)
{
    @autoreleasepool
    {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                                                        width:width
                                                                                       height:width
                                                                                    mipmapped:NO];
        desc.usage                 = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

        id<MTLTexture> texture = [deviceMtl newTextureWithDescriptor:desc];

        ScopedMetalTextureRef re(texture);
        return re;
    }
}

ScopedMetalTextureRef CreateMetalTextureCube(id<MTLDevice> deviceMtl,
                                             int width,
                                             MTLPixelFormat format)
{
    @autoreleasepool
    {
        MTLTextureDescriptor *desc =
            [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:format
                                                                  size:width
                                                             mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

        id<MTLTexture> texture = [deviceMtl newTextureWithDescriptor:desc];

        ScopedMetalTextureRef re(texture);
        return re;
    }
}

class ImageTestMetal : public ANGLETest
{
  protected:
    ImageTestMetal()
    {
        setWindowWidth(128);
        setWindowHeight(128);
        setConfigRedBits(8);
        setConfigGreenBits(8);
        setConfigBlueBits(8);
        setConfigAlphaBits(8);
        setConfigDepthBits(24);
    }

    void testSetUp() override
    {
        constexpr char kVS[] = "precision highp float;\n"
                               "attribute vec4 position;\n"
                               "varying vec2 texcoord;\n"
                               "\n"
                               "void main()\n"
                               "{\n"
                               "    gl_Position = position;\n"
                               "    texcoord = (position.xy * 0.5) + 0.5;\n"
                               "    texcoord.y = 1.0 - texcoord.y;\n"
                               "}\n";

        constexpr char kTextureFS[] = "precision highp float;\n"
                                      "uniform sampler2D tex;\n"
                                      "varying vec2 texcoord;\n"
                                      "\n"
                                      "void main()\n"
                                      "{\n"
                                      "    gl_FragColor = texture2D(tex, texcoord);\n"
                                      "}\n";
        constexpr char kTextureCubeFS[] =
            "precision highp float;\n"
            "uniform samplerCube tex;\n"
            "varying vec2 texcoord;\n"
            "\n"
            "void main()\n"
            "{\n"
            "    gl_FragColor = textureCube(tex, vec3(texcoord, 0.0));\n"
            "}\n";

        mTextureProgram = CompileProgram(kVS, kTextureFS);
        if (mTextureProgram == 0)
        {
            FAIL() << "shader compilation failed.";
        }

        mTextureUniformLocation = glGetUniformLocation(mTextureProgram, "tex");

        mTextureCubeProgram = CompileProgram(kVS, kTextureCubeFS);
        if (mTextureCubeProgram == 0)
        {
            FAIL() << "shader compilation failed.";
        }

        mTextureCubeUniformLocation = glGetUniformLocation(mTextureCubeProgram, "tex");

        ASSERT_GL_NO_ERROR();
    }

    void testTearDown() override
    {
        glDeleteProgram(mTextureProgram);
        glDeleteProgram(mTextureCubeProgram);
    }

    id<MTLDevice> getMtlDevice()
    {
        EGLAttrib angleDevice = 0;
        EGLAttrib device      = 0;
        EXPECT_EGL_TRUE(
            eglQueryDisplayAttribEXT(getEGLWindow()->getDisplay(), EGL_DEVICE_EXT, &angleDevice));

        EXPECT_EGL_TRUE(eglQueryDeviceAttribEXT(reinterpret_cast<EGLDeviceEXT>(angleDevice),
                                                EGL_MTL_DEVICE_ANGLE, &device));

        return (__bridge id<MTLDevice>)reinterpret_cast<void *>(device);
    }

    ScopedMetalTextureRef createMtlTexture2D(int width, int height, MTLPixelFormat format)
    {
        id<MTLDevice> device = getMtlDevice();

        return CreateMetalTexture2D(device, width, height, format);
    }

    ScopedMetalTextureRef createMtlTextureCube(int width, MTLPixelFormat format)
    {
        id<MTLDevice> device = getMtlDevice();

        return CreateMetalTextureCube(device, width, format);
    }

    void sourceMetalTarget2D_helper(const EGLint *attribs,
                                    int width,
                                    int height,
                                    MTLPixelFormat format,
                                    ScopedMetalTextureRef *metalTexture,
                                    EGLImageKHR *eglImage,
                                    GLuint *textureTarget);
    void sourceMetalTargetCube_helper(const EGLint *attribs,
                                      int size,
                                      MTLPixelFormat format,
                                      ScopedMetalTextureRef *metalTexture,
                                      EGLImageKHR *eglImage,
                                      GLuint *textureTarget);

    void sourceMetalSharedEvent_helper(ScopedMetalSharedEventRef *sharedEventMtlOut,
                                       GLuint *semaphoreOut);

    void clearTextureInMtl(id<MTLTexture> textureMtl,
                           id<MTLCommandBuffer> cmdBufferMtl,
                           const GLubyte data[4]);
    void clearTexture(GLuint texture, const GLubyte data[4]);

    void verifyResultsTexture(GLuint texture,
                              GLubyte data[4],
                              GLenum textureTarget,
                              GLuint program,
                              GLuint textureUniform)
    {
        // Draw a quad with the target texture
        glUseProgram(program);
        glBindTexture(textureTarget, texture);
        glUniform1i(textureUniform, 0);

        drawQuad(program, "position", 0.5f);

        // Expect that the rendered quad has the same color as the source texture
        EXPECT_PIXEL_NEAR(0, 0, data[0], data[1], data[2], data[3], 1.0);
    }

    void verifyResults2D(GLuint texture, GLubyte data[4])
    {
        verifyResultsTexture(texture, data, GL_TEXTURE_2D, mTextureProgram,
                             mTextureUniformLocation);
    }
    void verifyResultsCube(GLuint texture, GLubyte data[4])
    {
        verifyResultsTexture(texture, data, GL_TEXTURE_CUBE_MAP, mTextureCubeProgram,
                             mTextureCubeUniformLocation);
    }

    template <typename destType, typename sourcetype>
    destType reinterpretHelper(sourcetype source)
    {
        static_assert(sizeof(destType) == sizeof(size_t),
                      "destType should be the same size as a size_t");
        size_t sourceSizeT = static_cast<size_t>(source);
        return reinterpret_cast<destType>(sourceSizeT);
    }

    bool hasImageNativeMetalTextureExt() const
    {
        if (!IsMetal())
        {
            return false;
        }
        EGLAttrib angleDevice = 0;
        eglQueryDisplayAttribEXT(getEGLWindow()->getDisplay(), EGL_DEVICE_EXT, &angleDevice);
        if (!angleDevice)
        {
            return false;
        }
        auto extensionString = static_cast<const char *>(
            eglQueryDeviceStringEXT(reinterpret_cast<EGLDeviceEXT>(angleDevice), EGL_EXTENSIONS));
        if (strstr(extensionString, kDeviceMtlExt) == nullptr)
        {
            return false;
        }
        return IsEGLDisplayExtensionEnabled(getEGLWindow()->getDisplay(),
                                            kEGLMtlImageNativeTextureExt);
    }

    bool hasEglImageCubeExt() const { return IsGLExtensionEnabled(kEGLImageCubeExt); }

    bool hasOESExt() const { return IsGLExtensionEnabled(kOESExt); }

    bool hasBaseExt() const
    {
        return IsEGLDisplayExtensionEnabled(getEGLWindow()->getDisplay(), kBaseExt);
    }

    bool hasSemaphoreExts() const
    {
        return IsGLExtensionEnabled(kSemaphoreExt) && IsGLExtensionEnabled(kSemaphoreFdExt) &&
               IsGLExtensionEnabled(kSemaphoreTimelineExt);
    }

    GLuint mTextureProgram;
    GLint mTextureUniformLocation;

    GLuint mTextureCubeProgram;
    GLint mTextureCubeUniformLocation = -1;
};

void ImageTestMetal::sourceMetalTarget2D_helper(const EGLint *attribs,
                                                int width,
                                                int height,
                                                MTLPixelFormat format,
                                                ScopedMetalTextureRef *metalTextureOut,
                                                EGLImageKHR *eglImageOut,
                                                GLuint *textureTargetOut)
{
    EGLWindow *window = getEGLWindow();

    // Create MTLTexture
    ScopedMetalTextureRef textureMtl = createMtlTexture2D(width, height, format);

    // Create image
    EGLImageKHR image =
        eglCreateImageKHR(window->getDisplay(), EGL_NO_CONTEXT, EGL_MTL_TEXTURE_MGL,
                          reinterpret_cast<EGLClientBuffer>(textureMtl.get()), attribs);
    ASSERT_EGL_SUCCESS();

    // Create a texture target to bind the egl image
    GLuint target;
    glGenTextures(1, &target);
    glBindTexture(GL_TEXTURE_2D, target);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, image);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // return results
    *metalTextureOut  = std::move(textureMtl);
    *eglImageOut      = image;
    *textureTargetOut = target;
}

void ImageTestMetal::sourceMetalTargetCube_helper(const EGLint *attribs,
                                                  int size,
                                                  MTLPixelFormat format,
                                                  ScopedMetalTextureRef *metalTextureOut,
                                                  EGLImageKHR *eglImageOut,
                                                  GLuint *textureTargetOut)
{
    EGLWindow *window = getEGLWindow();

    // Create MTLTexture
    ScopedMetalTextureRef textureMtl = createMtlTextureCube(size, format);

    // Create image
    EGLImageKHR image =
        eglCreateImageKHR(window->getDisplay(), EGL_NO_CONTEXT, EGL_MTL_TEXTURE_MGL,
                          reinterpret_cast<EGLClientBuffer>(textureMtl.get()), attribs);
    ASSERT_EGL_SUCCESS();

    // Create a texture target to bind the egl image
    GLuint target;
    glGenTextures(1, &target);
    glBindTexture(GL_TEXTURE_CUBE_MAP, target);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_CUBE_MAP, image);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // return results
    *metalTextureOut  = std::move(textureMtl);
    *eglImageOut      = image;
    *textureTargetOut = target;
}

void ImageTestMetal::sourceMetalSharedEvent_helper(ScopedMetalSharedEventRef *sharedEventMtlOut,
                                                   GLuint *semaphoreOut)
{
    id<MTLDevice> deviceMtl = getMtlDevice();
    ScopedMetalSharedEventRef sharedEventMtl([deviceMtl newSharedEvent]);

    // Write to file and pass its fd to OpenGL.
    // NOTE: fd will be owned by OpenGL, so don't close it.
    char name[] = "/tmp/XXXXXX";
    int tmpFd;
    ASSERT_NE((tmpFd = mkstemp(name)), -1);
    unlink(name);

    void *sharedEventPtr = (__bridge void *)sharedEventMtl;
    pwrite(tmpFd, &sharedEventPtr, sizeof(sharedEventPtr), 0);

    // Import to OpenGL
    GLuint glSemaphore;
    glGenSemaphoresEXT(1, &glSemaphore);
    ASSERT_GL_NO_ERROR();

    glImportSemaphoreFdEXT(glSemaphore, GL_HANDLE_TYPE_OPAQUE_FD_EXT, tmpFd);
    ASSERT_GL_NO_ERROR();

    // Return values
    *sharedEventMtlOut = std::move(sharedEventMtl);
    *semaphoreOut      = glSemaphore;
}

void ImageTestMetal::clearTextureInMtl(id<MTLTexture> textureMtl,
                                       id<MTLCommandBuffer> cmdBufferMtl,
                                       const GLubyte data[4])
{
    ScopedMetalRef<MTLRenderPassDescriptor *> clearPassMtl(
        [MTLRenderPassDescriptor renderPassDescriptor]);
    clearPassMtl.get().colorAttachments[0].texture     = textureMtl;
    clearPassMtl.get().colorAttachments[0].loadAction  = MTLLoadActionClear;
    clearPassMtl.get().colorAttachments[0].storeAction = MTLStoreActionStore;
    clearPassMtl.get().colorAttachments[0].clearColor =
        MTLClearColorMake(data[0] / 255.0, data[1] / 255.0, data[2] / 255.0, data[3] / 255.0);

    ScopedMetalRef<id<MTLRenderCommandEncoder>> clearPassEncoderMtl(
        [cmdBufferMtl renderCommandEncoderWithDescriptor:clearPassMtl]);
    [clearPassEncoderMtl.get() endEncoding];
}

void ImageTestMetal::clearTexture(GLuint texture, const GLubyte data[4])
{
    GLFramebuffer fbo;
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    EXPECT_GL_NO_ERROR();
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    EXPECT_GL_NO_ERROR();
    EXPECT_GLENUM_EQ(glCheckFramebufferStatus(GL_FRAMEBUFFER), GL_FRAMEBUFFER_COMPLETE);
    EXPECT_GL_NO_ERROR();

    glClearColor(data[0] / 255.0f, data[1] / 255.0f, data[2] / 255.0f, data[3] / 255.0f);
    EXPECT_GL_NO_ERROR();
    glClear(GL_COLOR_BUFFER_BIT);
    EXPECT_GL_NO_ERROR();
}

// Testing source metal EGL image, target 2D texture
TEST_P(ImageTestMetal, SourceMetalTarget2D)
{
    ANGLE_SKIP_TEST_IF(!IsMetal());
    ANGLE_SKIP_TEST_IF(!hasOESExt() || !hasBaseExt());
    ANGLE_SKIP_TEST_IF(!hasImageNativeMetalTextureExt());

    GLubyte data[4] = {7, 51, 197, 231};

    ScopedMetalTextureRef textureMtl;

    EGLImageKHR eglImage;
    GLuint glTarget;
    sourceMetalTarget2D_helper(kDefaultAttribs, 1, 1, MTLPixelFormatRGBA8Unorm, &textureMtl,
                               &eglImage, &glTarget);

    // Write the data to the MTLTexture
    [textureMtl.get() replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                        mipmapLevel:0
                              slice:0
                          withBytes:data
                        bytesPerRow:sizeof(data)
                      bytesPerImage:0];

    // Use texture target bound to egl image as source and render to framebuffer
    // Verify that data in framebuffer matches that in the egl image
    verifyResults2D(glTarget, data);

    // Clean up
    eglDestroyImageKHR(getEGLWindow()->getDisplay(), eglImage);
    glDeleteTextures(1, &glTarget);
}

// Testing source metal EGL image, target Cube texture
TEST_P(ImageTestMetal, SourceMetalTargetCube)
{
    ANGLE_SKIP_TEST_IF(!IsMetal());
    ANGLE_SKIP_TEST_IF(!hasOESExt() || !hasBaseExt() || !hasEglImageCubeExt());
    ANGLE_SKIP_TEST_IF(!hasImageNativeMetalTextureExt());

    ScopedMetalTextureRef textureMtl;

    EGLImageKHR eglImage;
    GLuint glTarget;
    sourceMetalTargetCube_helper(kDefaultAttribs, 1, MTLPixelFormatRGBA16Float, &textureMtl,
                                 &eglImage, &glTarget);

    GLubyte data[4] = {7, 51, 197, 231};
    std::array<GLushort, 4> floatData{
        gl::float32ToFloat16(data[0] / 255.f), gl::float32ToFloat16(data[1] / 255.f),
        gl::float32ToFloat16(data[2] / 255.f), gl::float32ToFloat16(data[3] / 255.f)};

    // Write the data to the MTLTexture
    for (int face = 0; face < 6; ++face)
    {
        [textureMtl.get() replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                            mipmapLevel:0
                                  slice:face
                              withBytes:floatData.data()
                            bytesPerRow:floatData.size() * sizeof(floatData[0])
                          bytesPerImage:0];
    }

    // Use texture target bound to egl image as source and render to framebuffer
    // Verify that data in framebuffer matches that in the egl image
    verifyResultsCube(glTarget, data);

    // Clean up
    eglDestroyImageKHR(getEGLWindow()->getDisplay(), eglImage);
    glDeleteTextures(1, &glTarget);
}

// Testing texture interop drawing
TEST_P(ImageTestMetal, SourceMetalInteropDraws)
{
    ANGLE_SKIP_TEST_IF(!IsMetal());
    ANGLE_SKIP_TEST_IF(!hasOESExt() || !hasBaseExt());
    ANGLE_SKIP_TEST_IF(!hasImageNativeMetalTextureExt());
    ANGLE_SKIP_TEST_IF(!hasSemaphoreExts());

    constexpr int kWidth  = 4;
    constexpr int kHeight = 4;

    // Create interop texture
    ScopedMetalTextureRef sharedTextureMtl;

    EGLImageKHR eglImage;
    GLuint glTarget;
    sourceMetalTarget2D_helper(kDefaultAttribs, kWidth, kHeight, MTLPixelFormatRGBA8Unorm,
                               &sharedTextureMtl, &eglImage, &glTarget);

    // Create interop semaphore
    ScopedMetalSharedEventRef sharedEventMtl;
    GLuint glSemaphore;

    sourceMetalSharedEvent_helper(&sharedEventMtl, &glSemaphore);

    // 1: Use Metal to clear texture to desired color
    GLColor mtlData        = {7, 51, 197, 231};
    uint64_t eventTimeline = 0;

    id<MTLDevice> deviceMtl = getMtlDevice();
    ScopedMetalRef<id<MTLCommandQueue>> cmdQueueMtl([deviceMtl newCommandQueue]);
    ScopedMetalRef<id<MTLCommandBuffer>> cmdBufferMtl([cmdQueueMtl.get() commandBuffer]);

    clearTextureInMtl(sharedTextureMtl, cmdBufferMtl, mtlData.data());

    [cmdBufferMtl.get() encodeSignalEvent:sharedEventMtl value:++eventTimeline];
    [cmdBufferMtl.get() commit];

    // 2: Verify the result in OpenGL
    glSemaphoreParameterui64vEXT(glSemaphore, GL_TIMELINE_SEMAPHORE_VALUE_MGL, &eventTimeline);
    GLenum imageLayout = GL_LAYOUT_COLOR_ATTACHMENT_EXT;
    glWaitSemaphoreEXT(glSemaphore, 0, nullptr, 1, &glTarget, &imageLayout);
    verifyResults2D(glTarget, mtlData.data());

    // 3: clear texture to red in OpenGL
    GLColor redData = {255, 0, 0, 255};
    clearTexture(glTarget, redData.data());
    eventTimeline++;
    glSemaphoreParameterui64vEXT(glSemaphore, GL_TIMELINE_SEMAPHORE_VALUE_MGL, &eventTimeline);
    glSignalSemaphoreEXT(glSemaphore, 0, nullptr, 1, &glTarget, &imageLayout);

    // 4: Mix the final result in Metal (copy shared texture's color to first pixel of final
    // texture)
    ScopedMetalTextureRef finalTextureMtl =
        createMtlTexture2D(kWidth, kHeight, MTLPixelFormatRGBA8Unorm);
    cmdBufferMtl = ScopedMetalRef<id<MTLCommandBuffer>>([cmdQueueMtl.get() commandBuffer]);
    [cmdBufferMtl.get() encodeWaitForEvent:sharedEventMtl value:eventTimeline];

    GLColor blueData = {0, 0, 255, 255};
    clearTextureInMtl(finalTextureMtl, cmdBufferMtl, blueData.data());

    ScopedMetalRef<id<MTLBlitCommandEncoder>> blitEncoderMtl(
        [cmdBufferMtl.get() blitCommandEncoder]);
    [blitEncoderMtl.get() copyFromTexture:sharedTextureMtl
                              sourceSlice:0
                              sourceLevel:0
                             sourceOrigin:MTLOriginMake(0, 0, 0)
                               sourceSize:MTLSizeMake(1, 1, 1)
                                toTexture:finalTextureMtl
                         destinationSlice:0
                         destinationLevel:0
                        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitEncoderMtl.get() synchronizeResource:finalTextureMtl.get()];
    [blitEncoderMtl.get() endEncoding];

    [cmdBufferMtl.get() commit];

    // 5: Verify the final result
    [cmdBufferMtl.get() waitUntilCompleted];
    GLColor finalData[kHeight][kWidth];
    [finalTextureMtl.get() getBytes:finalData
                        bytesPerRow:kWidth * 4
                         fromRegion:MTLRegionMake2D(0, 0, kWidth, kHeight)
                        mipmapLevel:0];
    EXPECT_COLOR_NEAR(finalData[0][0], redData, 2);   // region with color from shared texture
    EXPECT_COLOR_NEAR(finalData[0][1], blueData, 2);  // region with color from clear op in Metal
    EXPECT_COLOR_NEAR(finalData[1][0], blueData, 2);  // region with color from clear op in Metal
    EXPECT_COLOR_NEAR(finalData[1][1], blueData, 2);  // region with color from clear op in Metal

    // Clean up
    eglDestroyImageKHR(getEGLWindow()->getDisplay(), eglImage);
    glDeleteTextures(1, &glTarget);
    glDeleteSemaphoresEXT(1, &glSemaphore);
}

// Use this to select which configurations (e.g. which renderer, which GLES major version) these
// tests should be run against.
ANGLE_INSTANTIATE_TEST(ImageTestMetal, ES2_METAL(), ES3_METAL());
}  // namespace angle
