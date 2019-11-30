# MetalANGLE - OpenGL ES to Apple Metal API Translation Layer

[![Build Status](https://travis-ci.com/kakashidinho/metalangle.svg?branch=master)](https://travis-ci.com/kakashidinho/metalangle)

This is a fork of Goolge's [ANGLE project](https://chromium.googlesource.com/angle/angle). It adds Metal API backend support.
Apple announced OpenGL (ES) deprecation in 2018. So the purpose of MetalANGLE is to allow OpenGL ES applications
to continue operate on Apple platforms by translating OpenGL ES draw calls to Metal draw calls under the hood.

### Current Metal backend implementation status
- MetalANGLE is being migrated into official ANGLE repo. So this repo might not get updated for a while.
- Almost all basic samples has been tested to work fine.
- __OpenGL ES 2.0__ functionalities are 100% completed.
- __Almost all of ANGLE end2end tests have been passed__. See [List of failed tests](src/libANGLE/renderer/metal/README.md#Failed-ANGLE-end2end-tests).
- __97.7% of OpenGL ES 2.0 conformance tests passed__. See [Khronos VK-GL-CTS](https://github.com/KhronosGroup/VK-GL-CTS).
- [MGLKit](src/libANGLE/renderer/metal/DevSetup.md#MGLKit) utilities classes have been added. Providing kind of similar functionalies to Apples's GLKit.
- [EXT_instanced_arrays](https://www.khronos.org/registry/OpenGL/extensions/EXT/EXT_instanced_arrays.txt)/[ANGLE_instanced_arrays](https://www.khronos.org/registry/OpenGL/extensions/ANGLE/ANGLE_instanced_arrays.txt) support has been added, giving instanced draw capabilities to MetalANGLE.
- [OES_depth_texture](https://www.khronos.org/registry/OpenGL/extensions/OES/OES_depth_texture.txt) support has been added.
- Urho3D engine's demos have been tested using MetalANGLE without issues. See [Urho3D's MetalANGLE integration testing branch](https://github.com/kakashidinho/Urho3D/tree/angle-metal-backend).
- ~~No `GL_TRIANGLE_FAN` & `GL_LINE_LOOP` support in draw calls yet.~~
- Metal doesn't allow buffer offset not being multiple of 4 bytes. Hence, draw calls that use unsupported offsets, strides,
and vertex formats will force MetalANGLE to do software conversions on CPU.
- MSAA is not supported yet.
- __Platforms supports__:
  - MetalANGLE only supports __MacOS 10.13+__ for Mac.
  - For iOS, the min supported version is __iOS 9.0__. However, Metal acceleration is only available
    for __iOS 11.0+__, any version prior to that will fall back to use native Apple OpenGL ES
    implementation instead of Metal. Furthermore, most of the sample apps are compiled for __iOS
    11.0+__. So if you want to test the sample apps on 10.0 devices and below, it won't run, except
    a few ones (e.g. MGLKitSampleApp_ios9.0).
  - iPhone 5 and below are not supported.
  - __MacCatalyst 13.0+__ is supported.
#### TODO lists
- Make sure it passes all ANGLE's tests.
- ~~Support `GL_TRIANGLE_FAN` & `GL_LINE_LOOP` by generating index buffer on the fly using Metal compute shader.~~
- Use compute shader to convert unsupported offsets, strides & vertex formats.
- Support MSAA.
- Support OpenGL ES 3.0.

## How to build Metal ANGLE for MacOS & iOS
View the [Metal backend's Dev setup instructions](src/libANGLE/renderer/metal/DevSetup.md).
Currently, for convenience, iOS version can be built using Xcode project provided in `ios/xcode` folder. The Xcode project also builds [MGLKit](src/libANGLE/renderer/metal/DevSetup.md#MGLKit) utilities wrapper library which provides `MGLContext`, `MGLLayer`, `MGLKView`, `MGLKViewController`, similar to Apple's provided GLKit classes such as `CAEAGLContext`, `CAEAGLLayer`, `GLKView`, `GLKViewController`. Please open `MGLKitSamples.xcodeproj` for example iOS app using this MGLKit library.

------
# Google's ANGLE - Almost Native Graphics Layer Engine

The goal of ANGLE is to allow users of multiple operating systems to seamlessly run WebGL and other
OpenGL ES content by translating OpenGL ES API calls to one of the hardware-supported APIs available
for that platform. ANGLE currently provides translation from OpenGL ES 2.0 and 3.0 to desktop
OpenGL, OpenGL ES, Direct3D 9, and Direct3D 11. Support for translation from OpenGL ES to Vulkan is
underway, and future plans include compute shader support (ES 3.1) and MacOS support.

### Level of OpenGL ES support via backing renderers

|                |  Direct3D 9   |  Direct3D 11     |   Desktop GL   |    GL ES      |    Vulkan     |    Metal      |
|----------------|:-------------:|:----------------:|:--------------:|:-------------:|:-------------:|:-------------:|
| OpenGL ES 2.0  |    complete   |    complete      |    complete    |   complete    |    complete   |  in progress  |
| OpenGL ES 3.0  |               |    complete      |    complete    |   complete    |  in progress  |               |
| OpenGL ES 3.1  |               |   in progress    |    complete    |   complete    |  in progress  |               |
| OpenGL ES 3.2  |               |                  |    planned     |    planned    |    planned    |               |

### Platform support via backing renderers

|             |    Direct3D 9  |   Direct3D 11  |   Desktop GL  |    GL ES    |   Vulkan    |    Metal    |
|------------:|:--------------:|:--------------:|:-------------:|:-----------:|:-----------:|:-----------:|
| Windows     |    complete    |    complete    |   complete    |   complete  |   complete  |             |
| Linux       |                |                |   complete    |             |   complete  |             |
| Mac OS X    |                |                |   complete    |             |             | in progress |
| iOS         |                |                |               |             |             | in progress |
| Chrome OS   |                |                |               |   complete  |   planned   |             |
| Android     |                |                |               |   complete  |   complete  |             |
| Fuchsia     |                |                |               |             | in progress |             |

ANGLE v1.0.772 was certified compliant by passing the ES 2.0.3 conformance tests in October 2011.
ANGLE also provides an implementation of the EGL 1.4 specification.

ANGLE is used as the default WebGL backend for both Google Chrome and Mozilla Firefox on Windows
platforms. Chrome uses ANGLE for all graphics rendering on Windows, including the accelerated
Canvas2D implementation and the Native Client sandbox environment.

Portions of the ANGLE shader compiler are used as a shader validator and translator by WebGL
implementations across multiple platforms. It is used on Mac OS X, Linux, and in mobile variants of
the browsers. Having one shader validator helps to ensure that a consistent set of GLSL ES shaders
are accepted across browsers and platforms. The shader translator can be used to translate shaders
to other shading languages, and to optionally apply shader modifications to work around bugs or
quirks in the native graphics drivers. The translator targets Desktop GLSL, Direct3D HLSL, and even
ESSL for native GLES2 platforms.

## Sources

ANGLE repository is hosted by Chromium project and can be
[browsed online](https://chromium.googlesource.com/angle/angle) or cloned with

    git clone https://chromium.googlesource.com/angle/angle


## Building

View the [Dev setup instructions](doc/DevSetup.md).

## Contributing

* Join our [Google group](https://groups.google.com/group/angleproject) to keep up to date.
* Join us on IRC in the #ANGLEproject channel on FreeNode.
* Join us on [Slack](https://chromium.slack.com) in the #angle channel.
* [File bugs](http://anglebug.com/new) in the [issue tracker](https://bugs.chromium.org/p/angleproject/issues/list) (preferably with an isolated test-case).
* [Choose an ANGLE branch](doc/ChoosingANGLEBranch.md) to track in your own project.


* Read ANGLE development [documentation](doc).
* Look at [pending](https://chromium-review.googlesource.com/q/project:angle/angle+status:open)
  and [merged](https://chromium-review.googlesource.com/q/project:angle/angle+status:merged) changes.
* Become a [code contributor](doc/ContributingCode.md).
* Use ANGLE's [coding standard](doc/CodingStandard.md).
* Learn how to [build ANGLE for Chromium development](doc/BuildingAngleForChromiumDevelopment.md).
* Get help on [debugging ANGLE](doc/DebuggingTips.md).
* Go through [ANGLE's orientation](doc/Orientation.md) and sift through [starter projects](doc/Starter-Projects.md).


* Read about WebGL on the [Khronos WebGL Wiki](http://khronos.org/webgl/wiki/Main_Page).
* Learn about implementation details in the [OpenGL Insights chapter on ANGLE](http://www.seas.upenn.edu/~pcozzi/OpenGLInsights/OpenGLInsights-ANGLE.pdf) and this [ANGLE presentation](https://drive.google.com/file/d/0Bw29oYeC09QbbHoxNE5EUFh0RGs/view?usp=sharing).
* Learn about the past, present, and future of the ANGLE implementation in [this presentation](https://docs.google.com/presentation/d/1CucIsdGVDmdTWRUbg68IxLE5jXwCb2y1E9YVhQo0thg/pub?start=false&loop=false).
* Watch a [short presentation](https://youtu.be/QrIKdjmpmaA) on the Vulkan back-end.
* Track the [dEQP test conformance](doc/dEQP-Charts.md)
* Read design docs on the [Vulkan back-end](src/libANGLE/renderer/vulkan/README.md)
* If you use ANGLE in your own project, we'd love to hear about it!
