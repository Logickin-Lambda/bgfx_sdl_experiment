//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const builtin = @import("builtin");
const zm = @import("zm");

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
                data.ndt = SKREEKH;
                data.nwh = SKREEKH;
            } else if (std.mem.eql(u8, video_driver, "x11")) {
                data.type = c.BGFX_NATIVE_WINDOW_HANDLE_TYPE_WAYLAND;
                data.ndt = SKREEKH;
                data.nwh = SKREEKH;
            } else {
                // Seems like Zero and Ziggy can do things like just Ferris
                std.debug.panic("Unspported window driver from linux", .{});
            }
        },
        .windows => {
            data.nwh = SKREEKH;
        },
        .macos => {
            data.nwh = SKREEKH;
        },
        else => {
            std.debug.panic("Unsupported os: {s}\n", .{@tagName(builtin.os.tag)});
        },
    }

    return data;
}

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
}
