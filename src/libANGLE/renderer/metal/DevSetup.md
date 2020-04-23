# MetalANGLE Development

MetalANGLE provides OpenGL ES 2.0 (partial ES 3.0 support) and EGL 1.4 libraries.  You can use these
to build and run OpenGL ES 2.0 applications on Mac and iOS that make uses of underlying Metal API.

## Development setup

### Version Control
ANGLE uses git for version control. If you are not familiar with git, helpful documentation can be
found at [http://git-scm.com/documentation](http://git-scm.com/documentation).

### Quick build with Xcode project
If you don't want to test MetalANGLE with ANGLE's test suites or OpenGL ES conformance tests, you
can use the Xcode project provided in `mac/xcode` & `ios/xcode` folders to quickly build the
`MetalANGLE.framework` as well as several sample apps.

Fetching dependencies:

- run `ios/xcode/fetchDepedencies.sh` script to retrieve third party dependencies.

MacOS version:

- Open `OpenGLES.xcodeproj` in `mac/xcode` folder.
- The target `MetalANGLE_mac` will build OpenGL ES framework named `MetalANGLE.framework`.
- If you want to build the sample app using [MGLKit](#MGLKit) library. Open `MGKitSamples.xcodeproj`
  instead of `OpenGLES.xcodeproj`, DO NOT open both at the same time. As `MGKitSamples.xcodeproj`
  will open the `OpenGLES.xcodeproj` inside its workspace.
- The sample app `MGLKitSampleApp_mac` demonstrates how to use `MGLKit` to setup view and GL context
  on macOS.
- See [MGLKit](#MGLKit) section for more info about how to port your apps from `EAGL`/`GLKit` to
  `MGLKit`.

iOS version:

- Open `OpenGLES.xcodeproj` in `ios/xcode` folder.
- The target `MetalANGLE` will build OpenGL ES framework named `MetalANGLE.framework`.
- If you want to build tvOS version, choose `MetalANGLE_tvos` target.
- __Note__: in order to test sample apps on real devices. You have to change their Bundle Identifier
  in Xcode to something you like, since only one development team can use one ID at a time. And this
  is global restriction across the globes. Once one person install the sample apps using his Apple
  developer profile, the ID configured will be registered for that developer only. And no other
  developers can use that ID to install to their device anymore.
- If you want to build the sample app using [MGLKit](#MGLKit) library. Open `MGKitSamples.xcodeproj`
  instead of `OpenGLES.xcodeproj`, DO NOT open both at the same time. As
  `MGKitSamples.xcodeproj`will open the `OpenGLES.xcodeproj` inside its workspace.
- Running and testing on iOS Simulator requires Xcode 11+ and MacOS Catalina (10.15+).
- The sample app `MGLKitSampleApp` demonstrates how to use `MGLKit` to setup view and GL context on
  iOS.
- The sample app `MGLKitSampleApp_tvos` demonstrates how to use `MGLKit` to setup view and GL
  context on tvOS.
- The sample app `MGLPaint` is a port of Apple's old `GLPaint` sample app.


### Standard ANGLE build with all test suites
The following is the standard building process of ANGLE project, which contains extensive test
targets to verify MetalANGLE implementation. Note that the standard ANGLE build process will produce
`libEGL.dylib`, `libGLESv2.dylib` & `libGLESv1CM.dylib` instead of `MetalANGLE.framework`. The
`.dylib` version doesn't contain [MGLKit](#MGLKit) wrapper classes as the framework version does.
Currently, it only supports building MacOS version.

##### Required Tools

On all platforms:

 * [depot_tools](http://dev.chromium.org/developers/how-tos/install-depot-tools)
   * Required to generate projects and fetch third-party dependencies.
   * Provides gclient, GN and ninja tools.
 * [Xcode](https://developer.apple.com/xcode/) for Clang and development files.
 * Bison and flex are not needed as we only support generating the translator grammar on Windows.

For MacOS build:

 * GN is the default build system.  GYP support has been removed. GN is available through
   depot_tools installation.
 * Clang will be set up by the build system and used by default.

##### Getting the source

```
git clone https://github.com/kakashidinho/metalangle
cd metalangle
python scripts/bootstrap.py
gclient sync
git checkout master
```

After running `gclient sync`, it may report some errors about failed to fetch
"gs://chromium-clang-format ...". If this happens, open `DEPS` file in the root directory, remove
this code snippets:
```
  {
    'name': 'clang_format_mac',
    'pattern': '.',
    'condition': 'host_os == "mac" and not build_with_chromium',
    'action': [ 'download_from_google_storage',
                '--no_resume',
                '--platform=darwin',
                '--no_auth',
                '--bucket', 'chromium-clang-format',
                '-s', '{angle_root}/buildtools/mac/clang-format.sha1',
    ],
  },
```

##### Building MacOS version

After getting the source successfully, you are ready to generate the ninja files:
```
gn gen out/Debug --ide=xcode --args='mac_deployment_target="10.13" angle_enable_metal=true'
```

GN will generate ninja files by default.  To change the default build options run `gn args
out/Debug`.  Some commonly used options are:
```
target_cpu = "x64"  (or "x86")
is_clang = false    (to use system default compiler instead of clang)
is_debug = true     (enable debugging, true is the default)
strip_absolute_paths_from_debug_symbols = false (disable this flag will allow xcode to debug the output binaries)
```
You can open Xcode workspace generated by GN in `out/Debug` folder to browse the code, as well as
debugging the tests and sample applications.

For a release build run `gn args out/Release` and set `is_debug = false`.

For more information on GN run `gn help`.

Ninja can be used to compile with one of the following commands:
```
ninja -C out/Debug
ninja -C out/Release
```
Ninja automatically calls GN to regenerate the build files on any configuration change. Ensure
`depot_tools` is in your path as it provides ninja.

## Application Development with ANGLE
This sections describes how to use ANGLE to build an OpenGL ES application.

### Choosing a Backend
ANGLE can use a variety of backing renderers based on platform.  On MacOS & iOS, it defaults to
Metal.

ANGLE provides an EGL extension called `EGL_ANGLE_platform_angle` which allows uers to select which
renderer to use at EGL initialization time by calling eglGetPlatformDisplayEXT with special enums.
Details of the extension can be found in it's specification in `extensions/ANGLE_platform_angle.txt`
and `extensions/ANGLE_platform_angle_*.txt` and examples of it's use can be seen in the ANGLE
samples and tests, particularly `util/EGLWindow.cpp`. Currently, iOS version cannot choose other
renderer other than the default (Metal).

### To Use MetalANGLE in Your Application

Configure your build environment to have access to the `include` folder to provide access to the
standard Khronos EGL and GLES2 header files.

#### On MacOS (using `libGLESv2.dylib` built by standard ANGLE build system)

 - Configure your build environment to have access to `libEGL.dylib` and `libGLESv2.dylib` found in
   the build output directory (see [Building ANGLE](#Building-MacOS-version)).
 - Link you application against `libGLESv2.dylib` and `libEGL.dylib`.
 - Code your application to the Khronos [OpenGL ES 2.0](http://www.khronos.org/registry/gles/) and
   [EGL 1.4](http://www.khronos.org/registry/egl/) APIs.

#### On iOS and MacOS (using `MetalANGLE.framework` built by the provided Xcode project)

 - Link you application against `MetalANGLE.framework`.

##### MGLKit
 - `MetalANGLE.framework` also contains MGLKit utilities classes such as `MGLContext`, `MGLLayer`,
   `MGLKView`, `MGLKViewController`, similar to Apple's provided GLKit classes such as
   `CAEAGLContext`, `CAEAGLLayer`, `GLKView`, `GLKViewController`. Please see the sample app making
   use of this MGLKit classes in `MGLKitSamples.xcodeproj`

##### Porting from Apple's EAGL & GLKit to MGLKit
- Apple's `EAGL` & `GLKit` classes provide high level APIs to manage OpenGL ES contexts and views.
  `MetalANGLE` provides similar classes but with different names, to port your apps from using
  `EAGL` & `GLKit` to use `MGLKit`, a bit of modifications have to be done.
  Even though most of the `MGLKit` classes mimic the same functionalities as Apple's respective
  ones, there are still some minor differences, for example, `CAEAGLLayer` requires devs to manually
  create default framebuffer's storage via `[EAGLContext renderbufferStorage: fromDrawable:]` call.
  On the other hand, `MGLLayer` automatically does it for you, so no need for manual default
  framebuffer creation.

- Equivalent classes:

|    Apple                      |     MetalANGLE           |
|-------------------------------|--------------------------|
|    EAGLContext                |      MGLContext          |
|    CAEAGLLayer                |      MGLLayer            |
|  EAGLRenderingAPI             |      MGLRenderingAPI     |
|    GLKView                    |      MGLKView            |
|   GLKViewDelegate             |      MGLKViewDelegate    |
|  GLKViewController            |      MGLKViewController  |
| GLKViewDrawableColorFormat    | MGLDrawableColorFormat   |
| GLKViewDrawableDepthFormat    | MGLDrawableDepthFormat   |
| GLKViewDrawableStencilFormat  | MGLDrawableStencilFormat |
| GLKViewDrawableMultisample    | MGLDrawableMultisample   |

- In typical old code, one usually configures  `[GLKViewController viewDidLoad]` with `EAGLContext` and `GLKView`:
```
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Create an OpenGL ES context and assign it to the view loaded from storyboard
    GLKView *view = (GLKView *)self.view;
    view.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    // Configure renderbuffers created by the view
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.drawableStencilFormat = GLKViewDrawableStencilFormat8;

    // Enable multisampling
    view.drawableMultisample = GLKViewDrawableMultisample4X;
}
```
- When porting the `MetalANGLE`, the above should be changed to `[MGLKViewController viewDidLoad]` like this:
```
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Create an OpenGL ES context and assign it to the view loaded from storyboard
    MGLKView *view = (MGLKView *)self.view;
    view.context = [[MGLContext alloc] initWithAPI:kMGLRenderingAPIOpenGLES2];

    // Configure renderbuffers created by the view
    view.drawableColorFormat = MGLDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = MGLDrawableDepthFormat24;
    view.drawableStencilFormat = MGLDrawableStencilFormat8;

    // Enable multisampling
    view.drawableMultisample = MGLDrawableMultisample4X;
}
```

- Alternatively, if the app uses `CAEAGLLayer` directly with a custom `UIView`, for example:
```
@interface PaintingView()
{
    EAGLContext *context;
    GLuint viewFramebuffer, viewRenderbuffer;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        eaglLayer.opaque = YES;
        // In this application, we want to retain the drawable contents after a call to presentRenderbuffer.
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking,
                      kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                      nil];

        // Set the view's scale factor as you wish
        self.contentScaleFactor = [[UIScreen mainScreen] scale];

        // Initialize OpenGL context
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        // Set context current
        if (!context || ![EAGLContext setCurrentContext:context]) {
            return nil;
        }

        // Allocate default framebuffer and renderbuffer:
        glGenFramebuffers(1, &viewFramebuffer);
        glGenRenderbuffers(1, &viewRenderbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);

        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);

        // Retrieve renderbuffer size
        GLint backingWidth, backingHeight;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
          NSLog(@"Failed to make complete framebuffer objectz %x",
                glCheckFramebufferStatus(GL_FRAMEBUFFER));
          return nil;
        }
    }

    return self;
}

- (void) renderFunc
{
    [EAGLContext setCurrentContext:context];

    // Clear the buffer
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}
@end
```

- If you use `MetalANGLE`, the above would be changed to the following (Note: unlike `CAEAGLLayer`,
`MGLLayer` automatically creates default framebuffer for you, so no need for creating custom
renderbuffer with `[EAGLContext renderbufferStorage: fromDrawable:]`):
```
@interface PaintingView()
{
    MGLContext *context;
}

+ (Class)layerClass
{
    return [MGLLayer class];
}

- (id)initWithCoder:(NSCoder*)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        MGLLayer *mglLayer = (MGLLayer *)self.layer;

        mglLayer.opaque = YES;
        // In this application, we want to retain the EAGLDrawable contents after a call to present.
        mglLayer.retainedBacking = YES:
        mglLayer.drawableColorFormat = MGLDrawableColorFormatRGBA8888;

        // Set the layer's scale factor as you wish
        mglLayer.contentScale = [[UIScreen mainScreen] scale];

        // Initialize OpenGL context
        context = [[MGLContext alloc] initWithAPI:kMGLRenderingAPIOpenGLES2];

        // Set context current without any active layer for now. It is perfectly fine to create
        // textures, buffers without any active layer. But before calling any GL draw commands,
        // you must call [MGLContext setCurrentContext: forLayer:], see renderFunc code below.
        if (!context || ![MGLContext setCurrentContext:context]) {
            return nil;
        }

        // Retrieve renderbuffer size.
        // NOTES:
        // - Unlike CAEAGLLayer, you don't need to manually create default framebuffer and
        //   renderbuffer. MGLLayer already creates them internally.
        // - The size could be changed at any time, for example when user resizes the view or
        //   rotates it on iOS devices. So it's better not to cache it.
        GLuint backingWidth, backingHeight;
        backingWidth = mglLayer.drawableSize.width;
        backingHeight = mglLayer.drawableSize.height;
    }

    return self;
}

- (void) renderFunc
{
    // Set layer as destination for drawing commands. NOTE: this is important, and must be called
    // before issuing any GL draw commands.
    MGLLayer *mglLayer = (MGLLayer *)self.layer;
    [MGLContext setCurrentContext:context forLayer:mglLayer];

    // Clear the buffer. The following glBindFramebuffer() call is optionally. Only needed if you
    // have custom framebuffers aside from the default one.
    glBindFramebuffer(GL_FRAMEBUFFER, mglLayer.defaultOpenGLFrameBufferID);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // Display the buffer
    [context present:mglLayer];
}

@end
```
