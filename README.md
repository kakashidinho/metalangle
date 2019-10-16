# MetalANGLE - OpenGL ES to Apple Metal API Translation Layer
This is a fork of Goolge's [ANGLE project](https://chromium.googlesource.com/angle/angle). It adds Metal API backend support.
Apple announced OpenGL (ES) deprecation in 2018. So the purpose of MetalANGLE is to allow OpenGL ES applications
to continue operate on Apple platforms by translating OpenGL ES draw calls to Metal draw calls under the hood.

### Current Metal backend implementation status
- MetalANGLE is being migrated into official ANGLE repo. So this repo might not get updated for a while.
- Almost all basic samples has been tested to work fine.
- __Over 90% of ANGLE end2end tests have been passed__. See [List of failed tests](src/libANGLE/renderer/metal/README.md#Failed-ANGLE-end2end-tests).
- ~~No `GL_TRIANGLE_FAN` & `GL_LINE_LOOP` support in draw calls yet.~~
- Metal doesn't allow buffer offset not being multiple of 4 bytes. Hence, draw calls that use unsupported offsets, strides,
and vertex formats will force MetalANGLE to do software conversions on CPU.
- MSAA is not supported yet.
- MetalANGLE only supports __MacOS 10.13+__ and __iOS 11.0+__.
#### TODO lists
- Make sure it passes all ANGLE's unit tests.
- ~~Support `GL_TRIANGLE_FAN` & `GL_LINE_LOOP` by generating index buffer on the fly using Metal compute shader.~~
- Use compute shader to convert unsupported offsets, strides & vertex formats.
- Support MSAA.
- Support OpenGL ES 3.0.

## How to build Metal ANGLE for MacOS & iOS
View the [Metal backend's Dev setup instructions](src/libANGLE/renderer/metal/DevSetup.md).
Currently, for convenience, iOS version can be built using Xcode project provided in `ios/xcode` folder. The Xcode project also builds [MGLKit](src/libANGLE/renderer/metal/DevSetup.md#MGLKit) utilities wrapper library which provides `MGLContext`, `MGLLayer`, `MGLKView`, `MGLKViewController`, similar the Apple's provided GLKit classes such as `CAEAGLContext`, `CAEAGLLayer`, `GLKView`, `GLKViewController`. Please open `MGLKitSamples.xcodeproj` for example iOS app using this MGLKit library.

------
# Google's ANGLE - Almost Native Graphics Layer Engine

The goal of ANGLE is to allow users of multiple operating systems to seamlessly run WebGL and other
OpenGL ES content by translating OpenGL ES API calls to one of the hardware-supported APIs available
for that platform. ANGLE currently provides translation from OpenGL ES 2.0 and 3.0 to desktop
OpenGL, OpenGL ES, Direct3D 9, and Direct3D 11. Support for translation from OpenGL ES to Vulkan is
underway, and future plans include compute shader support (ES 3.1) and MacOS support.

### Level of OpenGL ES support via backing renderers

|                |  Direct3D 9   |  Direct3D 11     |   Desktop GL   |    GL ES      |    Vulkan     |
|----------------|:-------------:|:----------------:|:--------------:|:-------------:|:-------------:|
| OpenGL ES 2.0  |    complete   |    complete      |    complete    |   complete    |    complete   |
| OpenGL ES 3.0  |               |    complete      |    complete    |   complete    |  in progress  |
| OpenGL ES 3.1  |               |   in progress    |    complete    |   complete    |  in progress  |
| OpenGL ES 3.2  |               |                  |    planned     |    planned    |    planned    |

### Platform support via backing renderers

|             |    Direct3D 9  |   Direct3D 11  |   Desktop GL  |    GL ES    |   Vulkan    |
|------------:|:--------------:|:--------------:|:-------------:|:-----------:|:-----------:|
| Windows     |    complete    |    complete    |   complete    |   complete  |   complete  |
| Linux       |                |                |   complete    |             |   complete  |
| Mac OS X    |                |                |   complete    |             |             |
| Chrome OS   |                |                |               |   complete  |   planned   |
| Android     |                |                |               |   complete  |   complete  |
| Fuchsia     |                |                |               |             | in progress |

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
