const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Detect target OS
    const is_windows = target.result.os.tag == .windows;

    // =====================
    // Build picotls first
    // =====================
    const picotls_dep = b.dependency("picotls", .{
        .target = target,
        .optimize = optimize,
    });

    const picotls_core = picotls_dep.artifact("picotls-core");
    const picotls_minicrypto = picotls_dep.artifact("picotls-minicrypto");

    // Common flags for all targets (Linux/Unix)
    const common_flags: []const []const u8 = &.{
        "-std=c11",
        "-Wall",
        "-DPTLS_WITHOUT_OPENSSL",
        "-DPTLS_WITHOUT_FUSION",
        "-DPICOQUIC_WITH_MINICRYPTO",
        "-D_GNU_SOURCE",
        "-pthread",
    };

    // Windows-specific flags
    const windows_flags: []const []const u8 = &.{
        "-std=c11",
        "-Wall",
        "-DPTLS_WITHOUT_OPENSSL",
        "-DPTLS_WITHOUT_FUSION",
        "-DPICOQUIC_WITH_MINICRYPTO",
        "-D_WINDOWS",
        "-DWIN32",
        "-Wl,--allow-multiple-definition",
    };

    const build_flags = if (is_windows) windows_flags else common_flags;

    // =====================
    // picoquic-core library
    // =====================
    const picoquic_library_files: []const []const u8 = &.{
        "picoquic/bbr.c",
        "picoquic/bbr1.c",
        "picoquic/bytestream.c",
        "picoquic/cc_common.c",
        "picoquic/config.c",
        "picoquic/cubic.c",
        "picoquic/c4.c",
        "picoquic/ech.c",
        "picoquic/error_names.c",
        "picoquic/fastcc.c",
        "picoquic/frames.c",
        "picoquic/intformat.c",
        "picoquic/logger.c",
        "picoquic/logwriter.c",
        "picoquic/loss_recovery.c",
        "picoquic/newreno.c",
        "picoquic/pacing.c",
        "picoquic/packet.c",
        "picoquic/paths.c",
        "picoquic/performance_log.c",
        "picoquic/picohash.c",
        "picoquic/picoquic_lb.c",
        "picoquic/picoquic_ptls_fusion.c",
        "picoquic/picoquic_ptls_minicrypto.c",
        "picoquic/picoquic_ptls_openssl.c",
        "picoquic/picoquic_mbedtls.c",
        "picoquic/picosocks.c",
        "picoquic/picosplay.c",
        "picoquic/port_blocking.c",
        "picoquic/prague.c",
        "picoquic/quicctx.c",
        "picoquic/register_all_cc_algorithms.c",
        "picoquic/sacks.c",
        "picoquic/sender.c",
        "picoquic/sim_link.c",
        "picoquic/siphash.c",
        "picoquic/sockloop.c",
        "picoquic/spinbit.c",
        "picoquic/ticket_store.c",
        "picoquic/timing.c",
        "picoquic/token_store.c",
        "picoquic/tls_api.c",
        "picoquic/transport.c",
        "picoquic/unified_log.c",
        "picoquic/util.c",
    };

    const picoquic_core_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Add include paths
    // For Windows: add zig_compat first to override Zig's MinGW headers with static inline versions
    if (is_windows) {
        picoquic_core_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    picoquic_core_module.addIncludePath(b.path("picoquic"));
    picoquic_core_module.addIncludePath(b.path("loglib"));
    picoquic_core_module.addIncludePath(b.path("picohttp"));
    picoquic_core_module.addIncludePath(picotls_dep.path("include"));
    picoquic_core_module.addIncludePath(picotls_dep.path("deps/cifra/src"));
    picoquic_core_module.addIncludePath(picotls_dep.path("deps/cifra/src/ext"));

    if (is_windows) {
        picoquic_core_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        picoquic_core_module.linkSystemLibrary("ws2_32", .{});
        picoquic_core_module.linkSystemLibrary("bcrypt", .{});
    } else {
        picoquic_core_module.linkSystemLibrary("pthread", .{});
    }

    picoquic_core_module.addCSourceFiles(.{
        .files = picoquic_library_files,
        .flags = build_flags,
    });

    const picoquic_core = b.addLibrary(.{
        .name = "picoquic-core",
        .linkage = .static,
        .root_module = picoquic_core_module,
    });

    picoquic_core.linkLibrary(picotls_core);
    picoquic_core.linkLibrary(picotls_minicrypto);

    b.installArtifact(picoquic_core);

    // =====================
    // picoquic-log library
    // =====================
    const loglib_files: []const []const u8 = &.{
        "loglib/autoqlog.c",
        "loglib/cidset.c",
        "loglib/csv.c",
        "loglib/logconvert.c",
        "loglib/logreader.c",
        "loglib/memory_log.c",
        "loglib/qlog.c",
        "loglib/svg.c",
    };

    const picoquic_log_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (is_windows) {
        picoquic_log_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    picoquic_log_module.addIncludePath(b.path("picoquic"));
    picoquic_log_module.addIncludePath(b.path("loglib"));
    picoquic_log_module.addIncludePath(b.path("picohttp"));
    picoquic_log_module.addIncludePath(picotls_dep.path("include"));
    picoquic_log_module.addIncludePath(picotls_dep.path("deps/cifra/src"));
    picoquic_log_module.addIncludePath(picotls_dep.path("deps/cifra/src/ext"));

    if (is_windows) {
        picoquic_log_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        picoquic_log_module.linkSystemLibrary("ws2_32", .{});
    } else {
        picoquic_log_module.linkSystemLibrary("pthread", .{});
    }

    picoquic_log_module.addCSourceFiles(.{
        .files = loglib_files,
        .flags = build_flags,
    });

    const picoquic_log = b.addLibrary(.{
        .name = "picoquic-log",
        .linkage = .static,
        .root_module = picoquic_log_module,
    });

    b.installArtifact(picoquic_log);

    // =====================
    // picohttp-core library
    // =====================
    const picohttp_files: []const []const u8 = &.{
        "picohttp/democlient.c",
        "picohttp/demoserver.c",
        "picohttp/h3zero.c",
        "picohttp/h3zero_client.c",
        "picohttp/h3zero_common.c",
        "picohttp/h3zero_server.c",
        "picohttp/h3zero_uri.c",
        "picohttp/h3zero_url_template.c",
        "picohttp/picomask.c",
        "picohttp/quicperf.c",
        "picohttp/webtransport.c",
        "picohttp/wt_baton.c",
    };

    const picohttp_core_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (is_windows) {
        picohttp_core_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    picohttp_core_module.addIncludePath(b.path("picoquic"));
    picohttp_core_module.addIncludePath(b.path("loglib"));
    picohttp_core_module.addIncludePath(b.path("picohttp"));
    picohttp_core_module.addIncludePath(picotls_dep.path("include"));
    picohttp_core_module.addIncludePath(picotls_dep.path("deps/cifra/src"));
    picohttp_core_module.addIncludePath(picotls_dep.path("deps/cifra/src/ext"));

    if (is_windows) {
        picohttp_core_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        picohttp_core_module.linkSystemLibrary("ws2_32", .{});
    } else {
        picohttp_core_module.linkSystemLibrary("pthread", .{});
    }

    picohttp_core_module.addCSourceFiles(.{
        .files = picohttp_files,
        .flags = build_flags,
    });

    const picohttp_core = b.addLibrary(.{
        .name = "picohttp-core",
        .linkage = .static,
        .root_module = picohttp_core_module,
    });

    picohttp_core.linkLibrary(picoquic_core);
    b.installArtifact(picohttp_core);

    // =======================
    // picoquicdemo executable
    // =======================
    const demo_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (is_windows) {
        demo_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    demo_module.addIncludePath(b.path("picoquic"));
    demo_module.addIncludePath(b.path("loglib"));
    demo_module.addIncludePath(b.path("picohttp"));
    demo_module.addIncludePath(picotls_dep.path("include"));
    demo_module.addIncludePath(picotls_dep.path("deps/cifra/src"));
    demo_module.addIncludePath(picotls_dep.path("deps/cifra/src/ext"));

    if (is_windows) {
        demo_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        demo_module.linkSystemLibrary("ws2_32", .{});
        demo_module.linkSystemLibrary("bcrypt", .{});
    } else {
        demo_module.linkSystemLibrary("pthread", .{});
    }

    demo_module.addCSourceFiles(.{
        .files = &.{
            "picoquicfirst/picoquicdemo.c",
            "picoquicfirst/getopt.c",
        },
        .flags = build_flags,
    });

    const picoquicdemo = b.addExecutable(.{
        .name = "picoquicdemo",
        .root_module = demo_module,
    });

    picoquicdemo.linkLibrary(picohttp_core);
    picoquicdemo.linkLibrary(picoquic_log);
    picoquicdemo.linkLibrary(picoquic_core);
    picoquicdemo.linkLibrary(picotls_minicrypto);
    picoquicdemo.linkLibrary(picotls_core);

    b.installArtifact(picoquicdemo);

    // =======================
    // picolog_t executable
    // =======================
    const picolog_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (is_windows) {
        picolog_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    picolog_module.addIncludePath(b.path("picoquic"));
    picolog_module.addIncludePath(b.path("loglib"));
    picolog_module.addIncludePath(picotls_dep.path("include"));

    if (is_windows) {
        picolog_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        picolog_module.linkSystemLibrary("ws2_32", .{});
        picolog_module.linkSystemLibrary("bcrypt", .{});
    } else {
        picolog_module.linkSystemLibrary("pthread", .{});
    }

    picolog_module.addCSourceFiles(.{
        .files = &.{"picolog/picolog.c"},
        .flags = build_flags,
    });

    const picolog_t = b.addExecutable(.{
        .name = "picolog_t",
        .root_module = picolog_module,
    });

    picolog_t.linkLibrary(picoquic_log);
    picolog_t.linkLibrary(picoquic_core);
    picolog_t.linkLibrary(picotls_minicrypto);
    picolog_t.linkLibrary(picotls_core);

    b.installArtifact(picolog_t);

    // =======================
    // picoquic_sample executable
    // =======================
    const sample_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (is_windows) {
        sample_module.addIncludePath(b.path("picoquic/zig_compat"));
    }
    sample_module.addIncludePath(b.path("picoquic"));
    sample_module.addIncludePath(b.path("loglib"));
    sample_module.addIncludePath(picotls_dep.path("include"));
    sample_module.addIncludePath(picotls_dep.path("deps/cifra/src"));
    sample_module.addIncludePath(picotls_dep.path("deps/cifra/src/ext"));

    if (is_windows) {
        sample_module.addIncludePath(picotls_dep.path("picotlsvs/picotls"));
        sample_module.linkSystemLibrary("ws2_32", .{});
        sample_module.linkSystemLibrary("bcrypt", .{});
    } else {
        sample_module.linkSystemLibrary("pthread", .{});
    }

    sample_module.addCSourceFiles(.{
        .files = &.{
            "sample/sample.c",
            "sample/sample_background.c",
            "sample/sample_client.c",
            "sample/sample_server.c",
        },
        .flags = build_flags,
    });

    const picoquic_sample = b.addExecutable(.{
        .name = "picoquic_sample",
        .root_module = sample_module,
    });

    picoquic_sample.linkLibrary(picoquic_log);
    picoquic_sample.linkLibrary(picoquic_core);
    picoquic_sample.linkLibrary(picotls_minicrypto);
    picoquic_sample.linkLibrary(picotls_core);

    b.installArtifact(picoquic_sample);
}
