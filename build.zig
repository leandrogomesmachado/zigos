const std = @import("std");

pub fn build(construtor: *std.Build) void {
    const destinoPadrao = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const otimizacao = construtor.standardOptimizeOption(.{});

    const bootRom = construtor.addExecutable(.{
        .name = "bootRom",
        .root_source_file = .{ .path = "boot/boot.zig" },
        .target = destinoPadrao,
        .optimize = otimizacao,
    });

    bootRom.setStackCheck(true);
    bootRom.setStackProtection(true);
    bootRom.single_threaded = true;

    const kernelImg = construtor.addExecutable(.{
        .name = "kernelImg",
        .root_source_file = .{ .path = "kernel/main.zig" },
        .target = destinoPadrao,
        .optimize = otimizacao,
    });

    kernelImg.setStackCheck(true);
    kernelImg.setStackProtection(true);
    kernelImg.single_threaded = true;

    const instalaBoot = construtor.addInstallArtifact(bootRom, .{});
    const instalaKernel = construtor.addInstallArtifact(kernelImg, .{});

    const passoBoot = construtor.step("boot", "Gera imagem bootRom");
    passoBoot.dependOn(&instalaBoot.step);

    const passoKernel = construtor.step("kernel", "Gera imagem kernelImg");
    passoKernel.dependOn(&instalaKernel.step);

    const comandoTeste = construtor.addSystemCommand(&[_][]const u8{
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "runTests.ps1",
    });

    const passoTeste = construtor.step("teste", "Gera imagem ext4 e executa QEMU");
    passoTeste.dependOn(&instalaKernel.step);
    passoTeste.dependOn(&comandoTeste.step);
}
