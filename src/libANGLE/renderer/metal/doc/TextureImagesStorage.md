# Texture images storage in Metal backend.

OpenGL spec allows a texture's images to be defined without consistent size and format through
glTexImage*, glCopyImage* calls. The texture when created, doesn't need to be complete.

During draw calls, the texture's images will be checked, if they are consistent in size and format,
the texture will be considered complete and thus can be used for rendering.

Metal textures (i.e. MTLTexture) on the hand only allow consistent defined images to be uploaded at any time.
The textures are already complete when they are created.

This is the overview of how Metal backend implements images storage for gl spec textures (TextureMtl):
1. Initially:
    * no actual MTLTexture is created yet.
    * glTexImage/glCopyImage(slice,level):
      * a single image (`images[slice][level]`: 2D/3D MTLTexture no mipmap + single slice) is created to store data for the texture at this level/slice.
    * glTexSubImage/glCopyTexSubImage(slice,level):
      * modifies the data of `images[slice][level]`;
2. If texture is complete at Draw/generateMip/FBO attachment call:
    * an actual MTLTexture object is created.
      - `images[0][0]` --> copy to actual texture's slice 0, level 0.
      - `images[0][1]` --> copy to actual texture's slice 0, level 1.
      - `images[0][2]` --> copy to actual texture's slice 0, level 2.
      - ...
    * The images will be destroyed, then re-created to become texture views of the actual texture at the specified level/slice.
      - `images[0][0]` -> view of actual texture's slice 0, level 0.
      - `images[0][1]` -> view of actual texture's slice 0, level 1.
      - `images[0][2]` -> view of actual texture's slice 0, level 2.
      - ...
3. After texture is complete:
    * glTexSubImage/glCopyTexSubImage(slice,level):
      * `images[slice][level]`'s content is modified, which means the actual texture's content at respective slice & level is modified also. Since the former is a view of the latter at given slice & level.
    * glTexImage/glCopyImage(slice,level):
      * If size != `images[slice][level]`.size():
        - Destroy actual texture (the other views are kept intact), recreate `images[slice][level]` as single image same as initial stage. The other views are kept intact so that texture data at those slice & level can be reused later.
      * else:
        - behaves as glTexSubImage/glCopyTexSubImage(slice,level).
