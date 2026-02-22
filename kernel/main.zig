const memoria = @import("memoria/gerenciador.zig");
const console = @import("controladores/serial.zig");
const bloco = @import("controladores/dispositivoBloco.zig");
const temporizador = @import("controladores/temporizador.zig");
const ext4 = @import("fs/ext4Leitor.zig");
const escalonador = @import("escalonador/escalonador.zig");

const blocoTamanhoPadrao: usize = 4096;

pub const ContextoKernel = struct {
    memoriaBase: u64 = 0,
    dtbEndereco: u64 = 0,
    stackInicial: u64 = 0,
    discoBase: u64 = 0,
    discoTamanho: usize = 0,
    intervaloTemporizador: u64 = 1000000,
};

pub fn kernelMain(contexto: *ContextoKernel) noreturn {
    console.inicializaConsole();
    temporizador.iniciaTemporizador(contexto.intervaloTemporizador);
    memoria.inicializaMemoria(.{
        .memoriaBase = contexto.memoriaBase,
        .dtbEndereco = contexto.dtbEndereco,
    });
    configuraDispositivo(contexto);
    const resultadoExt4 = ext4.inicializaLeitor(.{ .blocoTamanho = blocoTamanhoPadrao }) catch {
        console.escreveMensagem("falha ao iniciar ext4\n");
        travaExecucao();
    };
    _ = resultadoExt4;
    escalonador.iniciaEscalonador();
    travaExecucao();
}

fn travaExecucao() noreturn {
    while (true) {}
}

fn configuraDispositivo(contexto: *ContextoKernel) void {
    if (contexto.discoBase == 0) {
        console.escreveMensagem("disco nao definido\n");
        return;
    }
    if (contexto.discoTamanho == 0) {
        console.escreveMensagem("tamanho de disco invalido\n");
        return;
    }
    const ponteiro = @as([*]u8, @ptrFromInt(contexto.discoBase));
    bloco.inicializaDispositivo(.{
        .enderecoBase = ponteiro,
        .tamanhoTotal = contexto.discoTamanho,
        .blocoTamanho = blocoTamanhoPadrao,
    });
}
