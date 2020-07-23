//
// Copyright 2017 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
//    EGLTextureClientBufferTest: tests for the
//    EGL_MGL_mtl_texture_client_buffer/EGL_MGL_gl_texture_client_buffer extension.
//

#include "test_utils/ANGLETest.h"

#include "common/mathutil.h"
#include "test_utils/gl_raii.h"
#include "util/EGLWindow.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Metal/Metal.h>

using namespace angle;

namespace
{

class ScopeMetalTextureRef : angle::NonCopyable
{
  public:
    explicit ScopeMetalTextureRef(id<MTLTexture> surface) : mSurface(surface) {}

    ~ScopeMetalTextureRef()
    {
        if (mSurface)
        {
            release();
            mSurface = nullptr;
        }
    }

    id<MTLTexture> get() const { return mSurface; }

    // auto cast to MTLTexture
    operator id<MTLTexture>() const { return mSurface; }
    ScopeMetalTextureRef(const ScopeMetalTextureRef &other)
    {
        if (mSurface)
        {
            release();
        }
        mSurface = other.mSurface;
    }

    explicit ScopeMetalTextureRef(ScopeMetalTextureRef &&other)
    {
        if (mSurface)
        {
            release();
        }
        mSurface       = other.mSurface;
        other.mSurface = nil;
    }

    ScopeMetalTextureRef &operator=(ScopeMetalTextureRef &&other)
    {
        if (mSurface)
        {
            release();
        }
        mSurface       = other.mSurface;
        other.mSurface = nil;

        return *this;
    }

    ScopeMetalTextureRef &operator=(const ScopeMetalTextureRef &other)
    {
        if (mSurface)
        {
            release();
        }
        mSurface = other.mSurface;

        return *this;
    }

  private:
    void release()
    {
#if !__has_feature(objc_arc)
        [mSurface release];
#endif
    }

    id<MTLTexture> mSurface = nil;
};

ScopeMetalTextureRef CreateMetalTexture(id<MTLDevice> deviceMtl,
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

        ScopeMetalTextureRef re(texture);
        return re;
    }
}

}  // anonymous namespace

class MTLTextureClientBufferTest : public ANGLETest
{
  protected:
    MTLTextureClientBufferTest() : mConfig(0), mDisplay(nullptr) {}

    void testSetUp() override
    {
        mConfig  = getEGLWindow()->getConfig();
        mDisplay = getEGLWindow()->getDisplay();
    }

    EGLint getTextureTarget() const { return EGL_TEXTURE_2D; }

    GLint getGLTextureTarget() const { return GL_TEXTURE_2D; }

    ScopeMetalTextureRef createMtlTexture(int width, int height, MTLPixelFormat format)
    {
        EGLAttrib angleDevice = 0;
        EGLAttrib device      = 0;
        EXPECT_EGL_TRUE(
            eglQueryDisplayAttribEXT(getEGLWindow()->getDisplay(), EGL_DEVICE_EXT, &angleDevice));

        EXPECT_EGL_TRUE(eglQueryDeviceAttribEXT(reinterpret_cast<EGLDeviceEXT>(angleDevice),
                                                EGL_MTL_DEVICE_ANGLE, &device));

        return CreateMetalTexture((__bridge id<MTLDevice>)reinterpret_cast<void *>(device), width,
                                  height, format);
    }

    void createMTLTexturePbuffer(id<MTLTexture> textureMtl,
                                 EGLint width,
                                 EGLint height,
                                 GLenum internalFormat,
                                 GLenum type,
                                 EGLSurface *pbuffer) const
    {
        // clang-format off
        const EGLint attribs[] = {
            EGL_TEXTURE_INTERNAL_FORMAT_ANGLE, internalFormat,
            EGL_TEXTURE_TYPE_ANGLE,            type,
            EGL_TEXTURE_FORMAT,                EGL_TEXTURE_RGBA,
            EGL_TEXTURE_TARGET,                getTextureTarget(),
            EGL_NONE,                          EGL_NONE,
        };
        // clang-format on

        *pbuffer = eglCreatePbufferFromClientBuffer(
            mDisplay, EGL_MTL_TEXTURE_MGL, (__bridge EGLClientBuffer)textureMtl, mConfig, attribs);
        EXPECT_NE(EGL_NO_SURFACE, *pbuffer);
    }

    void bindMTLTextureToANGLEGLTexture(id<MTLTexture> textureMtl,
                                        EGLint width,
                                        EGLint height,
                                        GLenum internalFormat,
                                        GLenum type,
                                        EGLSurface *pbuffer,
                                        GLTexture *texture) const
    {
        createMTLTexturePbuffer(textureMtl, width, height, internalFormat, type, pbuffer);

        // Bind the pbuffer
        glBindTexture(getGLTextureTarget(), *texture);
        EGLBoolean result = eglBindTexImage(mDisplay, *pbuffer, EGL_BACK_BUFFER);
        EXPECT_EGL_TRUE(result);
        EXPECT_EGL_SUCCESS();
    }

    void doClearTest(id<MTLTexture> textureMtl,
                     GLenum internalFormat,
                     GLenum type,
                     void *data,
                     size_t dataSize)
    {
        // Bind the MTLTexture to a texture and clear it.
        EGLSurface pbuffer;
        GLTexture texture;
        bindMTLTextureToANGLEGLTexture(textureMtl, 1, 1, internalFormat, type, &pbuffer, &texture);

        GLFramebuffer fbo;
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        EXPECT_GL_NO_ERROR();
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, getGLTextureTarget(), texture,
                               0);
        EXPECT_GL_NO_ERROR();
        EXPECT_GLENUM_EQ(glCheckFramebufferStatus(GL_FRAMEBUFFER), GL_FRAMEBUFFER_COMPLETE);
        EXPECT_GL_NO_ERROR();

        glClearColor(1.0f / 255.0f, 2.0f / 255.0f, 3.0f / 255.0f, 4.0f / 255.0f);
        EXPECT_GL_NO_ERROR();
        glClear(GL_COLOR_BUFFER_BIT);
        EXPECT_GL_NO_ERROR();

        // Unbind pbuffer and check content.
        EGLBoolean result = eglReleaseTexImage(mDisplay, pbuffer, EGL_BACK_BUFFER);
        EXPECT_EGL_TRUE(result);
        EXPECT_EGL_SUCCESS();

        glFinish();

        std::vector<uint8_t> textureData(dataSize);
        [textureMtl getBytes:textureData.data()
                 bytesPerRow:dataSize
               bytesPerImage:0
                  fromRegion:MTLRegionMake2D(0, 0, 1, 1)
                 mipmapLevel:0
                       slice:0];

        ASSERT_EQ(0, memcmp(textureData.data(), data, dataSize));

        result = eglDestroySurface(mDisplay, pbuffer);
        EXPECT_EGL_TRUE(result);
        EXPECT_EGL_SUCCESS();
    }

    enum ColorMask
    {
        R = 1,
        G = 2,
        B = 4,
        A = 8,
    };
    void doSampleTest(id<MTLTexture> textureMtl,
                      GLenum internalFormat,
                      GLenum type,
                      void *data,
                      size_t dataSize,
                      int mask)
    {
        // Write the data to the MTLTexture
        [textureMtl replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                      mipmapLevel:0
                            slice:0
                        withBytes:data
                      bytesPerRow:dataSize
                    bytesPerImage:0];

        // Bind the MTLTexture to a texture and clear it.
        EGLSurface pbuffer;
        GLTexture texture;
        bindMTLTextureToANGLEGLTexture(textureMtl, 1, 1, internalFormat, type, &pbuffer, &texture);

        constexpr char kVS[] = "attribute vec4 position;\n"
                               "void main()\n"
                               "{\n"
                               "    gl_Position = vec4(position.xy, 0.0, 1.0);\n"
                               "}\n";
        constexpr char kFS_rect[] = "#extension GL_ARB_texture_rectangle : require\n"
                                    "precision mediump float;\n"
                                    "uniform sampler2DRect tex;\n"
                                    "void main()\n"
                                    "{\n"
                                    "    gl_FragColor = texture2DRect(tex, vec2(0, 0));\n"
                                    "}\n";
        constexpr char kFS_2D[] = "precision mediump float;\n"
                                  "uniform sampler2D tex;\n"
                                  "void main()\n"
                                  "{\n"
                                  "    gl_FragColor = texture2D(tex, vec2(0, 0));\n"
                                  "}\n";

        ANGLE_GL_PROGRAM(program, kVS,
                         (getTextureTarget() == EGL_TEXTURE_RECTANGLE_ANGLE ? kFS_rect : kFS_2D));
        glUseProgram(program);

        GLint location = glGetUniformLocation(program, "tex");
        ASSERT_NE(-1, location);
        glUniform1i(location, 0);

        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        drawQuad(program, "position", 0.5f, 1.0f, false);

        GLColor expectedColor((mask & R) ? 1 : 0, (mask & G) ? 2 : 0, (mask & B) ? 3 : 0,
                              (mask & A) ? 4 : 255);

        EXPECT_PIXEL_COLOR_EQ(0, 0, expectedColor);
        ASSERT_GL_NO_ERROR();
    }

    void doBlitTest(bool ioSurfaceIsSource, int width, int height)
    {
        // Create MTLTexture and bind it to a texture.
        ScopeMetalTextureRef textureMtl = createMtlTexture(width, height, MTLPixelFormatBGRA8Unorm);
        EGLSurface pbuffer;
        GLTexture texture;
        bindMTLTextureToANGLEGLTexture(textureMtl, width, height, GL_BGRA_EXT, GL_UNSIGNED_BYTE,
                                       &pbuffer, &texture);

        GLFramebuffer externalTextureFbo;
        glBindFramebuffer(GL_FRAMEBUFFER, externalTextureFbo);
        EXPECT_GL_NO_ERROR();
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, getGLTextureTarget(), texture,
                               0);
        EXPECT_GL_NO_ERROR();
        EXPECT_GLENUM_EQ(glCheckFramebufferStatus(GL_FRAMEBUFFER), GL_FRAMEBUFFER_COMPLETE);
        EXPECT_GL_NO_ERROR();

        // Create another framebuffer with a regular renderbuffer.
        GLFramebuffer fbo;
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        EXPECT_GL_NO_ERROR();
        GLRenderbuffer rbo;
        glBindRenderbuffer(GL_RENDERBUFFER, rbo);
        EXPECT_GL_NO_ERROR();
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, width, height);
        EXPECT_GL_NO_ERROR();
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rbo);
        EXPECT_GL_NO_ERROR();
        EXPECT_GLENUM_EQ(glCheckFramebufferStatus(GL_FRAMEBUFFER), GL_FRAMEBUFFER_COMPLETE);
        EXPECT_GL_NO_ERROR();

        glBindRenderbuffer(GL_RENDERBUFFER, 0);
        EXPECT_GL_NO_ERROR();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        EXPECT_GL_NO_ERROR();

        // Choose which is going to be the source and destination.
        GLFramebuffer &src = ioSurfaceIsSource ? externalTextureFbo : fbo;
        GLFramebuffer &dst = ioSurfaceIsSource ? fbo : externalTextureFbo;

        // Clear source to known color.
        glBindFramebuffer(GL_FRAMEBUFFER, src);
        glClearColor(1.0f / 255.0f, 2.0f / 255.0f, 3.0f / 255.0f, 4.0f / 255.0f);
        EXPECT_GL_NO_ERROR();
        glClear(GL_COLOR_BUFFER_BIT);
        EXPECT_GL_NO_ERROR();

        // Blit to destination.
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER_ANGLE, dst);
        glBlitFramebufferANGLE(0, 0, width, height, 0, 0, width, height, GL_COLOR_BUFFER_BIT,
                               GL_NEAREST);

        // Read back from destination.
        glBindFramebuffer(GL_FRAMEBUFFER, dst);
        GLColor expectedColor(1, 2, 3, 4);
        EXPECT_PIXEL_COLOR_EQ(0, 0, expectedColor);

        // Unbind pbuffer and check content.
        EGLBoolean result = eglReleaseTexImage(mDisplay, pbuffer, EGL_BACK_BUFFER);
        EXPECT_EGL_TRUE(result);
        EXPECT_EGL_SUCCESS();

        result = eglDestroySurface(mDisplay, pbuffer);
        EXPECT_EGL_TRUE(result);
        EXPECT_EGL_SUCCESS();
    }

    bool hasMetalExternalTextureExts() const
    {
        if (!IsMetal())
        {
            return false;
        }
        EGLAttrib angleDevice = 0;
        eglQueryDisplayAttribEXT(mDisplay, EGL_DEVICE_EXT, &angleDevice);
        if (!angleDevice)
        {
            return false;
        }
        auto extensionString = static_cast<const char *>(
            eglQueryDeviceStringEXT(reinterpret_cast<EGLDeviceEXT>(angleDevice), EGL_EXTENSIONS));
        if (strstr(extensionString, "EGL_ANGLE_device_mtl") == nullptr)
        {
            return false;
        }
        return IsEGLDisplayExtensionEnabled(mDisplay, "EGL_MGL_mtl_texture_client_buffer");
    }

    EGLConfig mConfig;
    EGLDisplay mDisplay;
};

// Test using BGRA8888 MTLTexture for rendering
TEST_P(MTLTextureClientBufferTest, RenderToBGRA8888MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatBGRA8Unorm);

    GLColor color(3, 2, 1, 4);
    doClearTest(textureMtl, GL_BGRA_EXT, GL_UNSIGNED_BYTE, &color, sizeof(color));
}

// Test reading from BGRA8888 MTLTexture
TEST_P(MTLTextureClientBufferTest, ReadFromBGRA8888MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatBGRA8Unorm);

    GLColor color(3, 2, 1, 4);
    doSampleTest(textureMtl, GL_BGRA_EXT, GL_UNSIGNED_BYTE, &color, sizeof(color), R | G | B | A);
}

// Test using RGBA8888 MTLTexture for rendering
TEST_P(MTLTextureClientBufferTest, RenderToRGBA8888MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatRGBA8Unorm);

    GLColor color(1, 2, 3, 4);
    doClearTest(textureMtl, GL_RGBA, GL_UNSIGNED_BYTE, &color, sizeof(color));
}

// Test reading from RGBA8888 MTLTexture
TEST_P(MTLTextureClientBufferTest, ReadFromRGBA8888MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatRGBA8Unorm);

    GLColor color(1, 2, 3, 4);
    doSampleTest(textureMtl, GL_RGBA, GL_UNSIGNED_BYTE, &color, sizeof(color), R | G | B | A);
}

// Test using R8 MTLTexture for rendering
TEST_P(MTLTextureClientBufferTest, RenderToR8MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatR8Unorm);

    uint8_t color = 1;
    doClearTest(textureMtl, GL_RED, GL_UNSIGNED_BYTE, &color, sizeof(color));
}

// Test reading from R8 MTLTexture
TEST_P(MTLTextureClientBufferTest, ReadFromR8MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatR8Unorm);

    uint8_t color = 1;
    doSampleTest(textureMtl, GL_RED, GL_UNSIGNED_BYTE, &color, sizeof(color), R);
}

// Test using R8G8 MTLTexture for rendering
TEST_P(MTLTextureClientBufferTest, RenderToRG88MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatRG8Unorm);

    uint8_t color[] = {1, 2};
    doClearTest(textureMtl, GL_RG, GL_UNSIGNED_BYTE, &color, sizeof(color));
}

// Test reading from R8G8 MTLTexture
TEST_P(MTLTextureClientBufferTest, ReadFromRG88MTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(1, 1, MTLPixelFormatRG8Unorm);

    uint8_t color[] = {1, 2};
    doSampleTest(textureMtl, GL_RG, GL_UNSIGNED_BYTE, &color, sizeof(color), R | G);
}

// Test blitting from MTLTexture
TEST_P(MTLTextureClientBufferTest, BlitFromMTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    doBlitTest(true, 2, 2);
}

// Test blitting to MTLTexture
TEST_P(MTLTextureClientBufferTest, BlitToMTLTexture)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    doBlitTest(false, 2, 2);
}

// Test MTLTexture pbuffers can be made current
TEST_P(MTLTextureClientBufferTest, MakeCurrent)
{
    ANGLE_SKIP_TEST_IF(!hasMetalExternalTextureExts());

    ScopeMetalTextureRef textureMtl = createMtlTexture(10, 10, MTLPixelFormatBGRA8Unorm);

    EGLSurface pbuffer;
    createMTLTexturePbuffer(textureMtl, 10, 10, GL_BGRA_EXT, GL_UNSIGNED_BYTE, &pbuffer);

    EGLContext context = getEGLWindow()->getContext();
    EGLBoolean result  = eglMakeCurrent(mDisplay, pbuffer, pbuffer, context);
    EXPECT_EGL_TRUE(result);
    EXPECT_EGL_SUCCESS();
    // The test harness expects the EGL state to be restored before the test exits.
    result = eglMakeCurrent(mDisplay, getEGLWindow()->getSurface(), getEGLWindow()->getSurface(),
                            context);
    EXPECT_EGL_TRUE(result);
    EXPECT_EGL_SUCCESS();
}

ANGLE_INSTANTIATE_TEST(MTLTextureClientBufferTest, ES2_METAL(), ES3_METAL());
