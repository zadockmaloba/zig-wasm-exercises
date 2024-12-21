const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        },
    });

    const lib = b.addSharedLibrary(.{
        .name = "zig-wasm-1",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    lib.import_memory = true;
    b.installArtifact(lib);

    const copy_resources = b.addSystemCommand(&.{
        "cp",
        "-rvf",
        "resources/",
        "zig-out/lib/",
    });
    copy_resources.step.dependOn(b.getInstallStep());

    const serve_file = b.addSystemCommand(&.{
        "python3",
        "-m",
        "http.server",
        "8080",
    });
    serve_file.setCwd(b.path("./zig-out/lib/"));
    serve_file.step.dependOn(&copy_resources.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&serve_file.step);
}
