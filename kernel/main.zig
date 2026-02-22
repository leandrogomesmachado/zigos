const memoria = @import("memoria/gerenciador.zig");
const console = @import("controladores/serial.zig");
const ext4 = @import("fs/ext4Leitor.zig");
const escalonador = @import("escalonador/escalonador.zig");

pub const ContextoKernel = struct {
    memoriaBase: u64 = 0,
    dtbEndereco: u64 = 0,
    stackInicial: u64 = 0,
};

pub fn kernelMain(contexto: *ContextoKernel) noreturn {
    console.inicializaConsole();
    memoria.inicializaMemoria(.{
        .memoriaBase = contexto.memoriaBase,
        .dtbEndereco = contexto.dtbEndereco,
    });
    ext4.inicializaLeitor(.{});
    escalonador.iniciaEscalonador();
    travaExecucao();
}

fn travaExecucao() noreturn {
    while (true) {}
}
