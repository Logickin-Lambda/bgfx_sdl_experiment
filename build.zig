const std = @import("std");
const zig_bgfx = @import("zig_bgfx");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "bgfx_example_code",
        .root_module = exe_mod,
    });

    // Let me try to default my program as Vulkan
    const bgfx = b.dependency("zig_bgfx", .{
        .optimize = optimize,
        .directx11 = false,
        .directx12 = false,
    });

    exe.linkLibrary(bgfx.artifact("bgfx"));

    const zm = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("zm", zm.module("zm"));

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    exe_mod.linkLibrary(sdl_lib);

    // This will be the hardest part of the project because we need to build
    // shaders using the given library which is rare for zig projects if this
    // is not the first time I have ever encounter such strategy.
    // The zig_bgfx library provides a function to compile the shaderc code
    // into different formats which we can toggle the type of backend as shown:
    const shader_dir = zig_bgfx.buildShaderDir(b, .{
        .target = target.result,
        .root_path = "shader_programs",
        .backend_configs = &.{
            .{ .name = "opengl", .shader_model = .@"140", .supported_platforms = &.{ .windows, .linux } },
            .{ .name = "vulkan", .shader_model = .spirv, .supported_platforms = &.{ .windows, .linux } },
            .{ .name = "directx", .shader_model = .s_5_0, .supported_platforms = &.{.windows} },
            .{ .name = "metal", .shader_model = .metal, .supported_platforms = &.{.macos} },
        },
    }) catch {
        @panic("failed to compile all shaders in path 'shaders'");
    };

    // we need to bind our shader programs as import so that our zig program can use it like other zig libraries.
    exe.root_module.addAnonymousImport("shaders_raw", .{
        .root_source_file = zig_bgfx.createShaderModule(b, shader_dir) catch {
            std.debug.panic("failed to create shader module from path 'shaders' ", .{});
        },
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // install shaders into zig-out
    const shader_dir_install = b.addInstallDirectory(.{
        .source_dir = shader_dir.files.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "my_shader_dir",
    });
    b.getInstallStep().dependOn(&shader_dir_install.step);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
