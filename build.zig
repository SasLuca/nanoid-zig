const std = @import("std");

pub fn build(b: *std.Build) void
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nanoid_mod = b.addModule("nanoid", .{ .root_source_file = b.path("src/root.zig")});

    // Setup default example
    const default_example_exe = b.addExecutable(.{
        .name = "default-example",
        .root_source_file = b.path("examples/default-example.zig"),
        .optimize = optimize,
        .target = target,
    });
    default_example_exe.root_module.addImport("nanoid", nanoid_mod);
    const default_example_run = b.addRunArtifact(default_example_exe);
    const default_example_step = b.step("default-example", "Run a simple example");
    default_example_step.dependOn(&default_example_run.step);

    // Setup custom alphabet example
    const custom_alphabet_example_exe = b.addExecutable(.{
        .name = "custom-alphabet-example",
        .root_source_file = b.path("examples/custom-alphabet-example.zig"),
        .optimize = optimize,
        .target = target,
    });
    custom_alphabet_example_exe.root_module.addImport("nanoid", nanoid_mod);
    const custom_alphabet_example_run = b.addRunArtifact(custom_alphabet_example_exe);
    const custom_alphabet_example_step = b.step("custom-alphabet-example", "Run a simple example");
    custom_alphabet_example_step.dependOn(&custom_alphabet_example_run.step);

    // Setup tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize
    });
    const main_tests_run = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests_run.step);
}