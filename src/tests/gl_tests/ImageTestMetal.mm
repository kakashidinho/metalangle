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
constexpr EGLint kDefaultAttribs[]            = {
    EGL_NONE,
};
}  // anonymous namespace

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

ScopeMetalTextureRef CreateMetalTexture2D(id<MTLDevice> deviceMtl,
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

ScopeMetalTextureRef CreateMetalTextureCube(id<MTLDevice> deviceMtl,
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

        ScopeMetalTextureRef re(texture);
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

    ScopeMetalTextureRef createMtlTexture2D(int width, int height, MTLPixelFormat format)
    {
        id<MTLDevice> device = getMtlDevice();

        return CreateMetalTexture2D(device, width, height, format);
    }

    ScopeMetalTextureRef createMtlTextureCube(int width, MTLPixelFormat format)
    {
        id<MTLDevice> device = getMtlDevice();

        return CreateMetalTextureCube(device, width, format);
    }

    void SourceMetalTarget2D_helper(const EGLint *attribs);
    void SourceMetalTargetCube_helper(const EGLint *attribs);

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

    GLuint mTextureProgram;
    GLint mTextureUniformLocation;

    GLuint mTextureCubeProgram;
    GLint mTextureCubeUniformLocation = -1;
};

void ImageTestMetal::SourceMetalTarget2D_helper(const EGLint *attribs)
{
    EGLWindow *window = getEGLWindow();

    ANGLE_SKIP_TEST_IF(!hasOESExt() || !hasBaseExt());
    ANGLE_SKIP_TEST_IF(!hasImageNativeMetalTextureExt());

    GLubyte data[4] = {7, 51, 197, 231};

    // Create MTLTexture
    ScopeMetalTextureRef textureMtl = createMtlTexture2D(1, 1, MTLPixelFormatRGBA8Unorm);

    // Create image
    EGLImageKHR image =
        eglCreateImageKHR(window->getDisplay(), EGL_NO_CONTEXT, EGL_MTL_TEXTURE_MGL,
                          reinterpret_cast<EGLClientBuffer>(textureMtl.get()), attribs);
    ASSERT_EGL_SUCCESS();

    // Write the data to the MTLTexture
    [textureMtl.get() replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                        mipmapLevel:0
                              slice:0
                          withBytes:data
                        bytesPerRow:sizeof(data)
                      bytesPerImage:0];

    // Create a texture target to bind the egl image
    GLuint target;
    glGenTextures(1, &target);
    glBindTexture(GL_TEXTURE_2D, target);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, image);

    // Use texture target bound to egl image as source and render to framebuffer
    // Verify that data in framebuffer matches that in the egl image
    verifyResults2D(target, data);

    // Clean up
    eglDestroyImageKHR(window->getDisplay(), image);
    glDeleteTextures(1, &target);
}

void ImageTestMetal::SourceMetalTargetCube_helper(const EGLint *attribs)
{
    EGLWindow *window = getEGLWindow();

    ANGLE_SKIP_TEST_IF(!hasOESExt() || !hasBaseExt() || !hasEglImageCubeExt());
    ANGLE_SKIP_TEST_IF(!hasImageNativeMetalTextureExt());

    GLubyte data[4] = {7, 51, 197, 231};
    std::array<GLushort, 4> floatData{
        gl::float32ToFloat16(data[0] / 255.f), gl::float32ToFloat16(data[1] / 255.f),
        gl::float32ToFloat16(data[2] / 255.f), gl::float32ToFloat16(data[3] / 255.f)};

    // Create MTLTexture
    ScopeMetalTextureRef textureMtl = createMtlTextureCube(1, MTLPixelFormatRGBA16Float);

    // Create image
    EGLImageKHR image =
        eglCreateImageKHR(window->getDisplay(), EGL_NO_CONTEXT, EGL_MTL_TEXTURE_MGL,
                          reinterpret_cast<EGLClientBuffer>(textureMtl.get()), attribs);
    ASSERT_EGL_SUCCESS();

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

    // Create a texture target to bind the egl image
    GLuint target;
    glGenTextures(1, &target);
    glBindTexture(GL_TEXTURE_CUBE_MAP, target);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_CUBE_MAP, image);

    // Use texture target bound to egl image as source and render to framebuffer
    // Verify that data in framebuffer matches that in the egl image
    verifyResultsCube(target, data);

    // Clean up
    eglDestroyImageKHR(window->getDisplay(), image);
    glDeleteTextures(1, &target);
}

// Testing source metal EGL image, target 2D texture
TEST_P(ImageTestMetal, SourceMetalTarget2D)
{
    ANGLE_SKIP_TEST_IF(!IsMetal());
    SourceMetalTarget2D_helper(kDefaultAttribs);
}

// Testing source metal EGL image, target Cube texture
TEST_P(ImageTestMetal, SourceMetalTargetCube)
{
    ANGLE_SKIP_TEST_IF(!IsMetal());
    SourceMetalTargetCube_helper(kDefaultAttribs);
}

// Use this to select which configurations (e.g. which renderer, which GLES major version) these
// tests should be run against.
ANGLE_INSTANTIATE_TEST(ImageTestMetal,
                       ES2_METAL(),
                       ES3_METAL());
}  // namespace angle
