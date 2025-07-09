//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const builtin = @import("builtin");
const zm = @import("zm");
const shaders_raw = @import("shaders_raw");

// Based on my understanding, the zig SDL library is actually not a zig library,
// but a collection of the original C library built with zig as a substitution
// to the original Cmake building method.
//
// Thus, we need to include the library in a C way instead.
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
    @cInclude("bgfx/c99/bgfx.h");
});

pub fn main() !void {
    // As usual, we need to initialize the window component
    // before drawing anything at the shader level.
    // In comparison with GLFW, seems the window creation process
    // is much easier because we don't need to feed a bunch config
    // like the version of OpenGL or various kind of properties
    // to generate a correct window, not even that nasty GLProc pointer.
    const width = 800;
    const height = 600;

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        sdlError("Failed to initialize SDL");
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("SDL and BGFX example", width, height, 0) orelse {
        sdlError("Failed to create SDL window");
    };
    defer c.SDL_DestroyWindow(window);

    // the following is to dealing with initializing the bgfx,
    // but from the original zig-bgfx has mentioned, C version
    // didn't provide a default struct for the initialization,
    // which it actually make sense because most of the case,
    // C struct are defaulted as zeros when they are created,
    // but this can be a hidden behavior which zig don't like it,
    // thus, we need to define all value of the struct, and it
    // turns out, zig can assign zero into an extern struct as shown:
    var bgfx_init = std.mem.zeroes(c.bgfx_init_t);

    // Count means to select the default render backend, basically "Auto"
    bgfx_init.type = c.BGFX_RENDERER_TYPE_COUNT;

    // This chooses the gpu adapter, None will points to the default GPU,
    // which is my ARC graphics in my laptop, or using intel HD graphics
    // instead of NVIDIA 1660ti in my old desktop.
    bgfx_init.vendorId = c.BGFX_PCI_ID_NONE;

    // Not sure what is the meaning initialization mask, but now I know
    // zig can get the maximum value of an integer in the math library.
    bgfx_init.capabilities = std.math.maxInt(u64);

    // The following properties are related to defining Resolution
    // setting its the buffer size, latencies and the reset behavior
    // of back buffer which is a buffer used for drawing the current frame,
    // opposing to the front buffer that stored the printed result from the
    // previous frame which is used for printing onto the screen.
    // With format, it defines the color profile of the buffer such that
    // the buffer can store all the color information for all pixels.
    // In this case, we choose 8bit RGBA texture format.
    bgfx_init.resolution.format = c.BGFX_TEXTURE_FORMAT_RGBA8;
    bgfx_init.resolution.width = width;
    bgfx_init.resolution.height = height;
    bgfx_init.resolution.reset = c.BGFX_RESET_VSYNC;

    // Not sure why is the original example needs 2; will mess around it. TODO
    bgfx_init.resolution.numBackBuffers = 2;

    // The following defines the maximum of threads and memory usage.
    // The encoder pulls rendering command form the given number of threads:
    bgfx_init.limits.maxEncoders = 8;

    // This set the size of the command buffer size
    bgfx_init.limits.minResourceCbSize = 64 << 10; // ~ 64kb

    // vertex buffer size which the buffer stores the coordination of the vertex
    bgfx_init.limits.transientVbSize = 6 << 20; // ~ 6mb

    // while index buffer stores the connection of the coordination, such as
    // forming a triangle, or building cubes.
    bgfx_init.limits.transientIbSize = 2 << 20; // ~ 2mb

    bgfx_init.platformData = getPlatformData(window);
    c.bgfx_set_platform_data(&bgfx_init.platformData);

    // According to the original bgfx example, macos need to set the initial frame to -1
    // Seems like it is something do to the render thread spawn, which some of the
    // os don't spawn a separated thread for rendering process, and if we force it to do
    // that, the program crashes. MacOS is one of the example such that we need to prevent
    // such thread to be spawn by setting the function to -1
    //
    // Besides, we have to tell bgfx about it before initialization; otherwise, this call
    // will have no effect.
    _ = c.bgfx_render_frame(-1);

    // bgfx initialization, a standard pattern in all low level library
    // from OpenGL to bgfx, even the SunVox library.
    if (!c.bgfx_init(&bgfx_init)) {
        std.debug.panic("Failed to initialize bgfx", .{});
    }
    defer c.bgfx_shutdown();

    // we can extract the name of the backend for debugging.
    // Initially, similar to OpenGL, they only return the id of the renderer.
    const renderer_type = c.bgfx_get_renderer_type();
    const backend_name = c.bgfx_get_renderer_name(renderer_type);
    std.debug.print("Using Backend: {s}\n", .{backend_name});

    // pick an shader based on the renderer_type we have fetched from the previous function
    // By default, for windows, we should expect to use directx, but since we have suppressed
    // the use of directx, the bgfx_get_renderer_type will get the next best renderer,
    // which is Vulkan in this example, which is the reason why the program prints Vulkan
    //
    // However, the real question is: which shader? Do we need to include every single variant
    // so that the program runs? This is where the bgfx shines because instead of writing all
    // vulkan, opengl, directx and metal variant, we only need to write a single "shaderc" shader
    // and compile it from the build system which it will compiles all the variants.
    // Once compiled, we can bind it with a name such that we can import the shader just like
    // a normal zig import.
    const shaders = switch (renderer_type) {
        c.BGFX_RENDERER_TYPE_OPENGL => shaders_raw.opengl,
        c.BGFX_RENDERER_TYPE_VULKAN => shaders_raw.vulkan,
        c.BGFX_RENDERER_TYPE_DIRECT3D11 => shaders_raw.directx,
        c.BGFX_RENDERER_TYPE_METAL => shaders_raw.metal,
        else => @panic("Unknown backend type"),
    };

    // Finally, there are something familiar from the OpenGL
    // defining the vertex and index buffer; but more importantly,
    // zig can do the exact fancy python assign trick, but we
    // need the function to return a struct in order to make it work.
    const vbh, const ibh = createCube();
    defer c.bgfx_destroy_vertex_buffer(vbh);
    defer c.bgfx_destroy_index_buffer(ibh);

    SKREEKH main 68
}

/// Now I have learnt something new today
/// seems like zig can have function no return, creating an oneway
/// path into the program, and we can prematurely exit the program
/// using process.exit(t).
pub fn sdlError(msg: []const u8) noreturn {
    std.log.err("{s}: {s}", .{ msg, c.SDL_GetError() });
    std.process.exit(1);
}

pub fn getPlatformData(window: *c.SDL_Window) c.bgfx_platform_data_t {
    // the following functions gets the windowing system information
    // which are display type and handles if there is one.
    var data = std.mem.zeroes(c.bgfx_platform_data_t);

    switch (builtin.os.tag) {
        // This might save my original confusing superbible code because it turns out
        // that std.mem.span is used for converting *c multi pointer into slices.
        .linux => {
            const video_driver = std.mem.span(c.SDL_GetCurrentVideoDriver() orelse {
                sdlError("Failed to get SDL video driver");
            });

            // So the video_driver are just strings turned into slice because we can
            // just do a string comparison:
            if (std.mem.eql(u8, video_driver, "x11")) {
                data.type = c.BGFX_NATIVE_WINDOW_HANDLE_TYPE_DEFAULT;
                data.ndt = getWindowPtrProperties(window, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER);
                data.nwh = getWindowIntProperties(window, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER);
            } else if (std.mem.eql(u8, video_driver, "x11")) {
                data.type = c.BGFX_NATIVE_WINDOW_HANDLE_TYPE_WAYLAND;
                data.ndt = getWindowIntProperties(window, c.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER);
                data.nwh = getWindowPtrProperties(window, c.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER);
            } else {
                // Seems like Zero and Ziggy can do things like just Ferris
                std.debug.panic("Unspported window driver from linux", .{});
            }
        },
        .windows => {
            data.nwh = getWindowPtrProperties(window, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER);
        },
        .macos => {
            data.nwh = getWindowPtrProperties(window, c.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER);
        },
        else => {
            std.debug.panic("Unsupported os: {s}\n", .{@tagName(builtin.os.tag)});
        },
    }

    return data;
}

pub fn getWindowPtrProperties(window: *c.SDL_Window, property_name: [:0]const u8) *anyopaque {

    // It returns the property id or 0 if the given property is not found
    const properties = c.SDL_GetWindowProperties(window);

    if (properties == 0) {
        sdlError("Failed to get the SDL window property ID with the property name.");
    }

    return c.SDL_GetPointerProperty(properties, property_name, null) orelse {
        std.debug.panic("Failed to get SDL window property '{s}'", .{property_name});
    };
}

pub fn getWindowIntProperties(window: *c.SDL_Window, property_name: [:0]const u8) *anyopaque {
    const properties = c.SDL_GetWindowProperties(window);

    if (properties == 0) {
        sdlError("Failed to get the SDL window property ID with the property name.");
    }

    // zero is possible for counting the properties, so we have to let zero to be valid even thought it might not.
    return @ptrFromInt(@as(usize, @intCast(c.SDL_GetNumberProperty(properties, property_name, 0))));
}

fn createCube() struct { c.bgfx_vertex_buffer_handle_t, c.bgfx_index_buffer_handle_t } {
    // define vertex layout? Not sure what it means yet.
    const Vertex = [6]f32; // Never thought of defining a type like this, learnt something today

    // bgfx_vertex_layout_s and bgfx_vertex_layout_t are... same?
    // Anyways, the following code are used to defining the layout of the incoming vertex data,
    // and in this example, it defines the first three float for the vertex location, followed
    // by next three float for the normal of the vertex:
    var layout = std.mem.zeroes(c.bgfx_vertex_layout_t);
    _ = c.bgfx_vertex_layout_begin(&bgfx_vertex_layout_t, c.BGFX_RENDERER_TYPE_NOOP);
    _ = c.bgfx_vertex_layout_add(
        &layout,
        c.BGFX_ATTRIB_POSITION,
        3,
        c.BGFX_ATTRIB_TYPE_FLOAT,
        false,
        false,
    );
    _ = c.bgfx_vertex_layout_add(
        &layout,
        c.BGFX_ATTRIB_NORMAL,
        3,
        c.BGFX_ATTRIB_TYPE_FLOAT,
        false,
        false,
    );
    c.bgfx_vertex_layout_end(&layout);

    // define all the vertices that forms a cube
    // Because the demo only spin the cube along with the z axis,
    // the bottom part of the cube never shows, thus skip that plane.
    // Thus:
    const vertex_cnt = 4 * 5; // discard the bottom face
    const vertices, const vertices_mem = bgfxAlloc(Vertex, vertex_cnt);

    // Based on the vertex layout, we need to define vertices with a group of six
    // The first three are the coordination of the vertex,
    // and the last three is the normal which is perpendicular to the plane
    // since the first four vertices represent as the top face of the cube,
    // the normal will pointing to upwards, thus 1 to z axis
    vertices[0] = .{ -1, -1, 1, 0, 0, 1 };
    vertices[1] = .{ 1, -1, 1, 0, 0, 1 };
    vertices[2] = .{ -1, 1, 1, 0, 0, 1 };
    vertices[3] = .{ 1, 1, 1, 0, 0, 1 };

    // The next face is the right side, so the normal stick towards right, and etc
    vertices[4] = .{ 1, -1, 1, 1, 0, 0 };
    vertices[5] = .{ 1, -1, -1, 1, 0, 0 };
    vertices[6] = .{ 1, 1, 1, 1, 0, 0 };
    vertices[7] = .{ 1, 1, -1, 1, 0, 0 };

    vertices[8] = .{ -1, -1, -1, -1, 0, 0 };
    vertices[9] = .{ -1, -1, 1, -1, 0, 0 };
    vertices[10] = .{ -1, 1, -1, -1, 0, 0 };
    vertices[11] = .{ -1, 1, 1, -1, 0, 0 };

    vertices[12] = .{ 1, -1, -1, 0, 0, -1 };
    vertices[13] = .{ -1, -1, -1, 0, 0, -1 };
    vertices[14] = .{ 1, 1, -1, 0, 0, -1 };
    vertices[15] = .{ -1, 1, -1, 0, 0, -1 };

    vertices[16] = .{ -1, 1, 1, 0, 1, 0 };
    vertices[17] = .{ 1, 1, 1, 0, 1, 0 };
    vertices[18] = .{ -1, 1, -1, 0, 1, 0 };
    vertices[19] = .{ 1, 1, -1, 0, 1, 0 };

    // Everything on graphical software are made with triangles;
    // thus, we need to define a set of rules to define how to
    // arrange a bunch of triangle such that it assembles as a cube.

    // A cube without bottom made of 5 square, and they all require 2 triangles to form a square face;
    // thus, the number of the index to represent all the connected vertex is the following:
    const index_cnt = 5 * 2 * 3;
    const indices, const indices_mem = bgfxAlloc(u32, index_cnt);

    // Unlike the example from the superbible, each face don't have a share vertex to another face,
    // meaning that we can simply assign the index with the same orientation with, offset by the
    // multiple of Nth face:

    // just like 0..5, but since the array have a type defined,
    // it doesn't require a cast for each of the iteration.
    for ([_]u32{ 0, 1, 2, 3, 4 }) |idx| {
        indices[idx * 6 + 0] = idx * 4 + 0;
        indices[idx * 6 + 1] = idx * 4 + 1;
        indices[idx * 6 + 2] = idx * 4 + 2;
        indices[idx * 6 + 3] = idx * 4 + 3;
        indices[idx * 6 + 4] = idx * 4 + 4;
        indices[idx * 6 + 5] = idx * 4 + 5;
    }

    // Lastly, create all the vertex buffer, and bgfx is more elegant because
    // it doesn't force us to binding the buffer after creating it.
    const vbh = c.bgfx_create_vertex_buffer(vertices_mem, &layout, c.BGFX_BUFFER_NONE);
    assertValidHandle(vbh);

    const ibh = c.bgfx_create_index_buffer(indices_mem, c.BGFX_BUFFER_INDEX32);
    assertValidHandle(ibh);

    return .{ vbh, ibh };
}

/// Seems like we can't use the zig allocator, but to stick with bgfx allocator.
/// I am also not going to touch it unless I manage to replicate the example.
/// Seems like allocation is similar to all other allocator I have used before,
/// except for doing an align cast which I will have a deeper later.
pub fn bgfxAlloc(comptime T: type, count: uzise) struct { []T, *const c.bgfx_memory_t } {
    const size: u32 = @intCast(count * @sizeOf(T));
    const memory: *const c.bgfx_memory_t = c.bgfx_alloc(@ptrCast(size)) orelse @panic("Out Of Memory Error");

    // Since the allocated memory is byte size, we need to align the index
    // size to the given type, thus an align cast.
    const ptr: [*]align(@alignOf(T)) T = @alignCast(@ptrCast(memory.data));

    // The ptr is used for assign values while memory used for passing into the bgfx functions
    return .{ ptr[0..count], memory };
}

fn assertValidHandle(handle: anytype) void {
    std.debug.assert(handle.idx != std.math.maxInt(u16));
}
