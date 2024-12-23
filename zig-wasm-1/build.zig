const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        },
    });

    const wasm_exe = b.addExecutable(.{
        .name = "zig-wasm-1",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    wasm_exe.export_table = true;
    wasm_exe.export_memory = true;
    wasm_exe.rdynamic = true;
    wasm_exe.entry = .disabled;
    b.installArtifact(wasm_exe);

    const copy_resources = b.addSystemCommand(&.{
        "cp",
        "-rvf",
        "resources/",
        "zig-out/bin/",
    });
    copy_resources.step.dependOn(b.getInstallStep());

    const serve_file = b.addSystemCommand(&.{
        "python3",
        "-m",
        "http.server",
        "8080",
    });
    serve_file.setCwd(b.path("./zig-out/bin/"));
    serve_file.step.dependOn(&copy_resources.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&serve_file.step);
}
