# gl_ClipDistance extension support in Metal back-end

OpenGL GLSL's `gl_ClipDistance` is equivalent to `[[clip_distance]]` attribute in the Metal Shading
Language. However, OpenGL supports disabling/enabling individual `gl_ClipDistance[i]` on the API
level side. Writing to `gl_ClipDistance[i]` in shader will be ignored if it is disabled. Metal
doesn't have any equivalent API to disable/enable the writing, though writing to a `clip_distance`
variable automatically enables it.

To implement this enabling/disabling API in Metal back-end:

- The shader compiler will translate each `gl_ClipDistance[i]` assignment to an assignment to
  `ANGLEClipDistance[i]` variable.
- A special driver uniform variable `clipDistancesEnabled` will contain one bit flag for each
  enabled `gl_ClipDistance[i]`. This variable supports up to 32 `gl_ClipDistance` indices.
- At the end of vertex shader, the enabled `gl_ClipDistance[i]` will be assigned the respective
  value from `ANGLEClipDistance[i]`. On the other hand, those disabled elements will be assigned
  zero value. This step is described in the following code:
    ```
    if (ANGLEUniforms.clipDistancesEnabled & (0x1 << index))
        gl_ClipDistance[index] = ANGLEClipDistance[index];
    else
        gl_ClipDistance[index] = 0;
    ```
- Additional optimizations:
    - Only those indices that are referenced in the original code will be used in the final step.
    - If the original code doesn't use `gl_ClipDistance`, then all the steps above will be omitted.