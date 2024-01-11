const std = @import("std");

const stderr_writer = std.io.getStdErr().writer();

const c_flags = [_][]const u8{};

const cxx_flags = [_][]const u8{
    // "${CMAKE_CXX_FLAGS}",
    "-std=c++17",
    "-g",
    "-Wall",
    "-D_GLIBCXX_USE_NANOSLEEP",
    "-DKCOV_LIBRARY_PREFIX=/tmp",
    // TODO: fix this for x86_64
    "-DKCOV_HAS_LIBBFD=0",
    // TODO: fix this for x86_64
    "-DKCOV_LIBFD_DISASM_STYLED=0",
};

const kcov_srcs_cpp = [_][]const u8{
    "src/capabilities.cc",
    "src/collector.cc",
    "src/configuration.cc",
    "src/engine-factory.cc",
    "src/engines/bash-engine.cc",
    "src/engines/system-mode-engine.cc",
    "src/engines/system-mode-file-format.cc",
    "src/engines/python-engine.cc",
    "src/filter.cc",
    "src/gcov.cc",
    "src/main.cc",
    "src/merge-file-parser.cc",
    "src/output-handler.cc",
    // ${DISASSEMBLER_SRCS}
    "src/parser-manager.cc",
    "src/reporter.cc",
    "src/source-file-cache.cc",
    "src/utils.cc",
    "src/writers/cobertura-writer.cc",
    "src/writers/codecov-writer.cc",
    "src/writers/json-writer.cc",
    // ${coveralls_SRCS}
    "src/writers/html-writer.cc",
    "src/writers/sonarqube-xml-writer.cc",
    "src/writers/writer-base.cc",
    "src/writers/nocover.cc",
    // ${ELF_SRCS}
    // ${MACHO_SRCS}
    // include/capabilities.hh
    // include/gcov.hh
    // include/reporter.hh
    // include/collector.hh
    // include/generated-data-base.hh
    // include/solib-handler.hh
    // include/configuration.hh
    // include/lineid.hh
    // include/swap-endian.hh
    // include/engine.hh
    // include/manager.hh
    // include/utils.hh
    // include/file-parser.hh
    // include/output-handler.hh
    // include/writer.hh
    // include/filter.hh
    // include/phdr_data.h
    "src/system-mode/file-data.cc",
};

const kcov_system_mode_srcs_cpp = [_][]const u8{
    "src/configuration.cc",
    "src/dummy-solib-handler.cc",
    "src/engine-factory.cc",
    "src/engines/system-mode-file-format.cc",
    "src/engines/ptrace.cc",
    "src/engines/ptrace_linux.cc",
    "src/filter.cc",
    "src/gcov.cc",
    // include/capabilities.hh
    // include/collector.hh
    // include/configuration.hh
    // include/engine.hh
    // include/file-parser.hh
    // include/filter.hh
    // include/gcov.hh
    // include/generated-data-base.hh
    // include/lineid.hh
    // include/manager.hh
    // include/output-handler.hh
    // include/phdr_data.h
    // include/reporter.hh
    // include/solib-handler.hh
    // include/swap-endian.hh
    // include/utils.hh
    // include/writer.hh
    "src/main-system-daemon.cc",
    "src/parser-manager.cc",
    "src/system-mode/file-data.cc",
    "src/system-mode/registration.cc",
    "src/utils.cc",
};

const solib_generated = [_][]const u8{};

const macho_srcs_cpp = [_][]const u8{
    "src/parsers/macho-parser.cc",
    "src/engines/mach-engine.cc",
};

const macho_srcs_c = [_][]const u8{
    "zig-out/generated/mach_excServer.c",
};

const elf_srcs_cpp = [_][]const u8{
    // TODO: fix linux etc
    "src/dummy-solib-handler.cc",
};

const disassembler_srcs_cpp = [_][]const u8{
    // TODO: fix x86_64
    "src/parsers/dummy-disassembler.cc",
};

const coveralls_srcs_cpp = [_][]const u8{
    // TODO: fix no coveralls
    "src/writers/coveralls-writer.cc",
};

const generated_srcs_cpp = [_][]const u8{
    "zig-out/generated/bash-redirector-library.cc",
    "zig-out/generated/bash-cloexec-library.cc",
    "zig-out/generated/python-helper.cc",
    "zig-out/generated/bash-helper.cc",
    "zig-out/generated/kcov-system-library.cc",
    "zig-out/generated/html-data-files.cc",
};

const generated_srcs_c = [_][]const u8{
    "zig-out/generated/version.c",
};

var global_build: *std.Build = undefined;
var install_bash_execve_redirector_lib: *std.Build.InstallArtifactStep = undefined;
var install_bash_tracefd_cloexec_lib: *std.Build.InstallArtifactStep = undefined;
var install_kcov_system_lib: *std.Build.InstallArtifactStep = undefined;
var install_exe: *std.Build.InstallArtifactStep = undefined;

pub fn build(b: *std.Build) void {
    global_build = b;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    install_bash_execve_redirector_lib = buildBashExecveRedirectorLib(b, target, optimize);
    install_bash_tracefd_cloexec_lib = buildBashTracefdCloexecLib(b, target, optimize);
    install_kcov_system_lib = buildKcovSystemLib(b, target, optimize);

    var gen_version_step = getGenVersionStep(b);
    _ = &gen_version_step;

    var generate_source_step = getGenerateSourceStep(b);
    generate_source_step.dependOn(&install_bash_execve_redirector_lib.step);
    generate_source_step.dependOn(&install_bash_tracefd_cloexec_lib.step);
    generate_source_step.dependOn(&install_kcov_system_lib.step);
    _ = &generate_source_step;

    const exe = b.addExecutable(.{
        .name = "kcov",
        .target = target,
        .optimize = optimize,
    });

    exe.step.dependOn(gen_version_step);
    exe.step.dependOn(generate_source_step);

    exe.addIncludePath(.{ .path = "src/include" });

    exe.addCSourceFiles(.{ .files = &kcov_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &disassembler_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &coveralls_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &elf_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &macho_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &macho_srcs_c, .flags = &c_flags });
    exe.addCSourceFiles(.{ .files = &generated_srcs_cpp, .flags = &cxx_flags });
    exe.addCSourceFiles(.{ .files = &generated_srcs_c, .flags = &c_flags });

    exe.linkSystemLibrary2("pthread", .{});
    exe.linkSystemLibrary2("zlib", .{});
    exe.linkSystemLibrary2("curl", .{});
    exe.linkSystemLibrary2("m", .{});
    exe.linkSystemLibrary2("openssl", .{});
    exe.linkSystemLibrary2("c++", .{});
    exe.linkSystemLibrary2("libdwarf", .{ .use_pkg_config = .yes });

    install_exe = b.addInstallArtifact(exe, .{});

    const sign_exe_step = b.step("sign_kcov", "Signing the kcov binary with an ad-hoc identity");
    sign_exe_step.makeFn = signExeMake;
    sign_exe_step.dependOn(&install_exe.step);

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(sign_exe_step);
    run_step.dependOn(&run_exe.step);
}

fn buildBashExecveRedirectorLib(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.Build.Step.InstallArtifact {
    const bash_execve_redirector_lib = b.addSharedLibrary(.{
        .name = "bash_execve_redirector",
        .target = target,
        .optimize = optimize,
    });
    bash_execve_redirector_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "src/engines/bash-execve-redirector.c",
        },
        .flags = &c_flags,
    });
    return b.addInstallArtifact(bash_execve_redirector_lib, .{});
}

fn buildBashTracefdCloexecLib(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.Build.Step.InstallArtifact {
    const bash_tracefd_cloexec_lib = b.addSharedLibrary(.{
        .name = "bash_tracefd_cloexec",
        .target = target,
        .optimize = optimize,
    });
    bash_tracefd_cloexec_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "src/engines/bash-tracefd-cloexec.c",
        },
        .flags = &c_flags,
    });
    return b.addInstallArtifact(bash_tracefd_cloexec_lib, .{});
}

fn buildKcovSystemLib(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.Build.Step.InstallArtifact {
    const kcov_system_lib = b.addSharedLibrary(.{
        .name = "kcov_system_lib",
        .target = target,
        .optimize = optimize,
    });
    kcov_system_lib.addIncludePath(.{ .path = "src/include" });
    kcov_system_lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "src/engines/system-mode-binary-lib.cc",
            "src/utils.cc",
            "src/system-mode/registration.cc",
        },
        .flags = &cxx_flags,
    });
    kcov_system_lib.linkSystemLibrary2("c++", .{});
    kcov_system_lib.linkSystemLibrary2("zlib", .{});
    kcov_system_lib.linkSystemLibrary2("curl", .{});

    return b.addInstallArtifact(kcov_system_lib, .{});
}

/// Spawns a child process, waits for it, collecting stdout and stderr, and then returns.
/// If it succeeds, the caller owns result.stdout and result.stderr memory.
pub fn runChildProcess(args: struct {
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
    cwd_dir: ?std.fs.Dir = null,
    env_map: ?*const std.process.EnvMap = null,
    max_output_bytes: usize = 50 * 1024,
    expand_arg0: std.ChildProcess.Arg0Expand = .no_expand,
    stdin_input: ?[]const u8,
}) anyerror!std.ChildProcess.RunResult {
    var child = std.ChildProcess.init(args.argv, args.allocator);
    child.stdin_behavior = if (args.stdin_input == null) .Ignore else .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = args.cwd;
    child.cwd_dir = args.cwd_dir;
    child.env_map = args.env_map;
    child.expand_arg0 = args.expand_arg0;

    var stdout = std.ArrayList(u8).init(args.allocator);
    var stderr = std.ArrayList(u8).init(args.allocator);
    errdefer {
        stdout.deinit();
        stderr.deinit();
    }

    try child.spawn();

    if (args.stdin_input) |si| {
        try child.stdin.?.writeAll(si);
        child.stdin.?.close();
        child.stdin = null;
    }

    try child.collectOutput(&stdout, &stderr, args.max_output_bytes);

    return std.ChildProcess.RunResult{
        .term = try child.wait(),
        .stdout = try stdout.toOwnedSlice(),
        .stderr = try stderr.toOwnedSlice(),
    };
}

fn runCommandAndGetResult(allocator: std.mem.Allocator, command: []const []const u8, input: ?[]const u8, panic_msg: []const u8) []const u8 {
    const MAX_OUTPUT = 8 * 1024 * 1024 * 1024;
    const rr = runChildProcess(.{
        .allocator = allocator,
        .argv = command,
        .cwd_dir = std.fs.cwd(),
        .max_output_bytes = MAX_OUTPUT,
        .stdin_input = input,
    }) catch @panic(panic_msg);
    switch (rr.term) {
        .Exited => |ret| {
            // std.debug.print("\nret = {any}\n", .{ret});
            if (ret == 0) {
                return std.mem.trim(u8, rr.stdout, " \t\n\r");
            } else {
                stderr_writer.print("Command: {s} exited with {d}! Error!\n", .{ command, ret }) catch {};
            }
        },
        .Signal => |ret| {
            stderr_writer.print("Command: {s} exited with signal {d}! Error!", .{ command, ret }) catch {};
            // stderr.print("==== stdout ====\n{?s}\n==== stderr ====\n{?s}\n", .{ child.stdout, child.stderr }) catch {};
            @panic(panic_msg);
        },
        .Stopped => |ret| {
            stderr_writer.print("Command: {s} stopped with {d}! Error!", .{ command, ret }) catch {};
            // stderr.print("==== stdout ====\n{?s}\n==== stderr ====\n{?s}\n", .{ child.stdout, child.stderr }) catch {};
            @panic(panic_msg);
        },
        .Unknown => |ret| {
            stderr_writer.print("Command: {s} exited with unknown reason {d}! Error!", .{ command, ret }) catch {};
            // stderr.print("==== stdout ====\n{?s}\n==== stderr ====\n{?s}\n", .{ child.stdout, child.stderr }) catch {};
            @panic(panic_msg);
        },
    }

    defer {
        allocator.free(rr.stdout);
        allocator.free(rr.stderr);
    }
    stderr_writer.print("==== stdout ====\n{s}\n==== stderr ====\n{s}\n", .{ rr.stdout, rr.stderr }) catch {};
    @panic(panic_msg);
}

fn runCommandsAndGetResult(allocator: std.mem.Allocator, commands: []const []const []const u8, panic_msg: []const u8) []const u8 {
    var last_stdout: []const u8 = undefined;
    for (commands, 0..) |command, i| {
        last_stdout = runCommandAndGetResult(
            allocator,
            command,
            if (i == 0) null else last_stdout,
            panic_msg,
        );
    }
    return last_stdout;
}

fn genVersionMake(self: *std.Build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    _ = self;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    _ = &arena;
    defer arena.deinit();
    var allocator = arena.allocator();
    _ = &allocator;

    const cwd = std.fs.cwd();

    const pod_version = brk: {
        var v: []const u8 = undefined;
        cwd.access(".git", .{}) catch {
            v = runCommandsAndGetResult(allocator, &[_][]const []const u8{
                &.{ "head", "-n", "1", "Changelog" },
                &.{ "cut", "-d", "(", "-f", "2" },
                &.{ "cut", "-d", ")", "-f", "1" },
            }, "run command head to get version failed.");
            break :brk v;
        };

        // do not try to download git as originam CMakeList does. Do you guys have git?
        v = runCommandAndGetResult(allocator, &[_][]const u8{
            "git", "--git-dir=./.git", "describe", "--abbrev=4", "HEAD",
        }, null, "run command git to get version failed.");
        break :brk v;
    };

    const f = try cwd.createFile("./zig-out/generated/version.c", .{});
    defer f.close();
    try f.writer().print("const char *kcov_version = \"{s}\";", .{pod_version});
}

fn getGenVersionStep(b: *std.Build) *std.Build.Step {
    const step = b.step("gen_version", "gen version.c from .git or ChangeLog");
    step.makeFn = genVersionMake;
    return step;
}

fn generateSourceStepMake(self: *std.Build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    _ = self;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    _ = &arena;
    defer arena.deinit();
    var allocator = arena.allocator();
    _ = &allocator;

    const cwd = std.fs.cwd();

    {
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            "data/bcov.css",
            "css_text",
            "data/amber.png",
            "icon_amber",
            "data/glass.png",
            "icon_glass",
            "data/source-file.html",
            "source_file_text",
            "data/index.html",
            "index_text",
            "data/js/handlebars.js",
            "handlebars_text",
            "data/js/kcov.js",
            "kcov_text",
            "data/js/jquery.min.js",
            "jquery_text",
            "data/js/jquery.tablesorter.min.js",
            "tablesorter_text",
            "data/js/jquery.tablesorter.widgets.min.js",
            "tablesorter_widgets_text",
            "data/tablesorter-theme.css",
            "tablesorter_theme_text",
        }, null, "run bin-to-c-source for html-data-files.cc");

        const f = try cwd.createFile("./zig-out/generated/html-data-files.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        const kcov_system_lib_path = install_kcov_system_lib.emitted_bin.?.getPath(global_build);
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            kcov_system_lib_path,
            "kcov_system_library",
        }, null, "run bin-to-c-source for kcov-system-library.cc");

        const f = try cwd.createFile("./zig-out/generated/kcov-system-library.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            "src/engines/bash-helper.sh",
            "bash_helper",
            "src/engines/bash-helper-debug-trap.sh",
            "bash_helper_debug_trap",
        }, null, "run bin-to-c-source for bash-helper.cc");

        const f = try cwd.createFile("./zig-out/generated/bash-helper.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        const bash_evecve_director_lib_path = install_bash_execve_redirector_lib.emitted_bin.?.getPath(global_build);
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            bash_evecve_director_lib_path,
            "bash_redirector_library",
        }, null, "run bin-to-c-source for bash-redirector-library.cc");

        const f = try cwd.createFile("./zig-out/generated/bash-redirector-library.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        const bash_tracefd_cloexec_lib_path = install_bash_tracefd_cloexec_lib.emitted_bin.?.getPath(global_build);
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            bash_tracefd_cloexec_lib_path,
            "bash_cloexec_library",
        }, null, "run bin-to-c-source for bash-cloexec-library.cc");

        const f = try cwd.createFile("./zig-out/generated/bash-cloexec-library.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        const out = runCommandAndGetResult(allocator, &[_][]const u8{
            "src/bin-to-c-source.py",
            "src/engines/python-helper.py",
            "python_helper",
        }, null, "run bin-to-c-source for python-helper.cc");

        const f = try cwd.createFile("./zig-out/generated/python-helper.cc", .{});
        try f.writer().print("{s}", .{out});
        defer f.close();
    }

    {
        _ = runCommandAndGetResult(allocator, &[_][]const u8{
            "mig",
            "src/engines/osx/mach_exc.defs",
        }, null, "run mig for mach_excServer.c");
        _ = runCommandAndGetResult(allocator, &[_][]const u8{
            "mv",
            "mach_exc.h",
            "zig-out/generated/",
        }, null, "mv mach_exe.h");
        _ = runCommandAndGetResult(allocator, &[_][]const u8{
            "mv",
            "mach_excServer.c",
            "zig-out/generated/",
        }, null, "mv mach_excServer.c");
        _ = runCommandAndGetResult(allocator, &[_][]const u8{
            "mv",
            "mach_excUser.c",
            "zig-out/generated/",
        }, null, "mv mach_excUser.c");
    }
}

fn getGenerateSourceStep(b: *std.Build) *std.Build.Step {
    const step = b.step("generate_source", "generate various sources");
    step.makeFn = generateSourceStepMake;
    return step;
}

fn signExeMake(self: *std.Build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    _ = self;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    _ = &arena;
    defer arena.deinit();
    var allocator = arena.allocator();
    _ = &allocator;

    const cwd = std.fs.cwd();
    _ = cwd;

    if (false) {
        return error.OOM;
    }

    _ = runCommandAndGetResult(allocator, &[_][]const u8{
        "codesign",
        "-s",
        "-",
        "--entitlements",
        "osx-entitlements.xml",
        "-f",
        "zig-out/bin/kcov",
    }, null, "Signing the kcov binary with an ad-hoc identity");
}
