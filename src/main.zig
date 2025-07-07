//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const buildin = @import("builtin");
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
}
