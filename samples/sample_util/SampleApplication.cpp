//
// Copyright 2013 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "SampleApplication.h"

#include "common/debug.h"
#include "util/EGLWindow.h"
#include "util/gles_loader_autogen.h"
#include "util/random_utils.h"
#include "util/test_utils.h"

#include <string.h>
#include <iostream>
#include <utility>

#if defined(ANGLE_PLATFORM_WINDOWS)
#    include "util/windows/WGLWindow.h"
#endif  // defined(ANGLE_PLATFORM_WINDOWS)

// Use environment variable if this variable is not compile time defined.
#if !defined(ANGLE_EGL_LIBRARY_NAME)
#    define ANGLE_EGL_LIBRARY_NAME angle::GetEnvironmentVar("ANGLE_EGL_LIBRARY_NAME").c_str()
#endif

namespace
{
const char *kUseAngleArg = "--use-angle=";
const char *kUseGlArg    = "--use-gl=native";

using DisplayTypeInfo = std::pair<const char *, EGLint>;

const DisplayTypeInfo kDisplayTypes[] = {
    {"d3d9", EGL_PLATFORM_ANGLE_TYPE_D3D9_ANGLE},
    {"d3d11", EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE},
    {"gl", EGL_PLATFORM_ANGLE_TYPE_OPENGL_ANGLE},
    {"gles", EGL_PLATFORM_ANGLE_TYPE_OPENGLES_ANGLE},
    {"metal", EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE},
    {"null", EGL_PLATFORM_ANGLE_TYPE_NULL_ANGLE},
    {"swiftshader", EGL_PLATFORM_ANGLE_TYPE_VULKAN_ANGLE},
    {"vulkan", EGL_PLATFORM_ANGLE_TYPE_VULKAN_ANGLE},
};

EGLint GetDisplayTypeFromArg(const char *displayTypeArg)
{
    for (const auto &displayTypeInfo : kDisplayTypes)
    {
        if (strcmp(displayTypeInfo.first, displayTypeArg) == 0)
        {
            std::cout << "Using ANGLE back-end API: " << displayTypeInfo.first << std::endl;
            return displayTypeInfo.second;
        }
    }

    std::cout << "Unknown ANGLE back-end API: " << displayTypeArg << std::endl;
    return EGL_PLATFORM_ANGLE_TYPE_DEFAULT_ANGLE;
}

EGLint GetDeviceTypeFromArg(const char *displayTypeArg)
{
    if (strcmp(displayTypeArg, "swiftshader") == 0)
    {
        return EGL_PLATFORM_ANGLE_DEVICE_TYPE_SWIFTSHADER_ANGLE;
    }
    else
    {
        return EGL_PLATFORM_ANGLE_DEVICE_TYPE_HARDWARE_ANGLE;
    }
}
}  // anonymous namespace

SampleApplication::SampleApplication(std::string name,
                                     int argc,
                                     char **argv,
                                     EGLint glesMajorVersion,
                                     EGLint glesMinorVersion,
                                     uint32_t width,
                                     uint32_t height)
    : mName(std::move(name)),
      mWidth(width),
      mHeight(height),
      mRunning(false),
      mGLWindow(nullptr),
      mEGLWindow(nullptr),
      mOSWindow(nullptr),
      mDriverType(angle::GLESDriverType::AngleEGL)
{
    mPlatformParams.renderer = EGL_PLATFORM_ANGLE_TYPE_DEFAULT_ANGLE;
    bool useNativeGL         = false;

    for (int argIndex = 1; argIndex < argc; argIndex++)
    {
        if (strncmp(argv[argIndex], kUseAngleArg, strlen(kUseAngleArg)) == 0)
        {
            const char *arg            = argv[argIndex] + strlen(kUseAngleArg);
            mPlatformParams.renderer   = GetDisplayTypeFromArg(arg);
            mPlatformParams.deviceType = GetDeviceTypeFromArg(arg);
        }

        if (strncmp(argv[argIndex], kUseGlArg, strlen(kUseGlArg)) == 0)
        {
            useNativeGL = true;
        }
    }

    mOSWindow = OSWindow::New();

    // Load EGL library so we can initialize the display.
    if (useNativeGL)
    {
#if defined(ANGLE_PLATFORM_WINDOWS)
        mGLWindow = WGLWindow::New(glesMajorVersion, glesMinorVersion);
        mEntryPointsLib.reset(angle::OpenSharedLibrary("opengl32", angle::SearchType::SystemDir));
        mDriverType = angle::GLESDriverType::SystemWGL;
#else
        mGLWindow = EGLWindow::New(glesMajorVersion, glesMinorVersion);
        mEntryPointsLib.reset(
            angle::OpenSharedLibraryWithExtension(angle::GetNativeEGLLibraryNameWithExtension()));
        mDriverType = angle::GLESDriverType::SystemEGL;
#endif  // defined(ANGLE_PLATFORM_WINDOWS)
    }
    else
    {
        mGLWindow = mEGLWindow = EGLWindow::New(glesMajorVersion, glesMinorVersion);
        mEntryPointsLib.reset(
            angle::OpenSharedLibrary(ANGLE_EGL_LIBRARY_NAME, angle::SearchType::ApplicationDir));
    }
}

SampleApplication::~SampleApplication()
{
    GLWindowBase::Delete(&mGLWindow);
    OSWindow::Delete(&mOSWindow);
}

bool SampleApplication::initialize()
{
    return true;
}

void SampleApplication::destroy() {}

void SampleApplication::step(float dt, double totalTime) {}

void SampleApplication::draw() {}

void SampleApplication::swap()
{
    mGLWindow->swap();
}

OSWindow *SampleApplication::getWindow() const
{
    return mOSWindow;
}

EGLConfig SampleApplication::getConfig() const
{
    ASSERT(mEGLWindow);
    return mEGLWindow->getConfig();
}

EGLDisplay SampleApplication::getDisplay() const
{
    ASSERT(mEGLWindow);
    return mEGLWindow->getDisplay();
}

EGLSurface SampleApplication::getSurface() const
{
    ASSERT(mEGLWindow);
    return mEGLWindow->getSurface();
}

EGLContext SampleApplication::getContext() const
{
    ASSERT(mEGLWindow);
    return mEGLWindow->getContext();
}

int SampleApplication::prepareToRun()
{
    mOSWindow->setVisible(true);

    ConfigParameters configParams;
    configParams.redBits     = 8;
    configParams.greenBits   = 8;
    configParams.blueBits    = 8;
    configParams.alphaBits   = 8;
    configParams.depthBits   = 24;
    configParams.stencilBits = 8;

    if (!mGLWindow->initializeGL(mOSWindow, mEntryPointsLib.get(), mDriverType, mPlatformParams,
                                 configParams))
    {
        return -1;
    }

    // Disable vsync
    if (!mGLWindow->setSwapInterval(0))
    {
        return -1;
    }

    mRunning = true;

    if (!initialize())
    {
        mRunning = false;
        return -1;
    }

    mTimer.start();
    mPrevTime = 0.0;

    return 0;
}

int SampleApplication::runIteration()
{
    double elapsedTime = mTimer.getElapsedTime();
    double deltaTime   = elapsedTime - mPrevTime;

    step(static_cast<float>(deltaTime), elapsedTime);

    // Clear events that the application did not process from this frame
    Event event;
    while (popEvent(&event))
    {
        // If the application did not catch a close event, close now
        switch (event.Type)
        {
            case Event::EVENT_CLOSED:
                exit();
                break;
            case Event::EVENT_KEY_RELEASED:
                onKeyUp(event.Key);
                break;
            case Event::EVENT_KEY_PRESSED:
                onKeyDown(event.Key);
                break;
            default:
                break;
        }
    }

    if (!mRunning)
    {
        return 0;
    }

    draw();
    swap();

    mOSWindow->messageLoop();

    mPrevTime = elapsedTime;

    return 0;
}

int SampleApplication::run()
{
    if (!mOSWindow->initialize(mName, mWidth, mHeight))
    {
        return -1;
    }

    int result = 0;
    if (mOSWindow->hasOwnLoop())
    {
        // The Window platform has its own message loop, so let it run its own
        // using our delegates.
        result = mOSWindow->runOwnLoop([this] { return prepareToRun(); },
                                       [this] { return runIteration(); });
    }
    else
    {
        if ((result = prepareToRun()))
        {
            return result;
        }

        while (mRunning)
        {
            runIteration();
        }
    }

    destroy();
    mGLWindow->destroyGL();
    mOSWindow->destroy();

    return result;
}

void SampleApplication::exit()
{
    mRunning = false;
}

bool SampleApplication::popEvent(Event *event)
{
    return mOSWindow->popEvent(event);
}

void SampleApplication::onKeyUp(const Event::KeyEvent &keyEvent)
{
    // Default no-op.
}

void SampleApplication::onKeyDown(const Event::KeyEvent &keyEvent)
{
    // Default no-op.
}
