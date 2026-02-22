const std = @import("std");

pub const ParametrosExt4 = struct {
    blocoTamanho: u32 = 4096,
};

pub const Superbloco = packed struct {
    inodesQuantidade: u32,
    blocosQuantidade: u32,
    reservado: u32,
    blocosLivres: u32,
    inodosLivres: u32,
    primeiroBloco: u32,
    blocoTamanhoExp: u32,
    fragmentoTamanhoExp: u32,
    blocosPorGrupo: u32,
    inodosPorGrupo: u32,
    gruposQuantidade: u32,
    magic: u16,
    estado: u16,
    flags: u16,
    verificacao: u16,
};

pub const LeitorExt4 = struct {
    parametros: ParametrosExt4,
    superbloco: Superbloco,
};

var estadoExt4 = LeitorExt4{
    .parametros = ParametrosExt4{},
    .superbloco = undefined,
};

pub fn inicializaLeitor(parametros: ParametrosExt4) void {
    estadoExt4.parametros = parametros;
    carregaSuperbloco();
    validaMagic();
}

pub fn lerInodo(indice: u32) void {
    std.mem.doNotOptimizeAway(indice);
}

pub fn lerBloco(indice: u32, destino: []u8) void {
    std.mem.doNotOptimizeAway(indice);
    std.mem.doNotOptimizeAway(destino);
}

fn carregaSuperbloco() void {
    var superblocoTemp = Superbloco{
        .inodesQuantidade = 0,
        .blocosQuantidade = 0,
        .reservado = 0,
        .blocosLivres = 0,
        .inodosLivres = 0,
        .primeiroBloco = 0,
        .blocoTamanhoExp = 2,
        .fragmentoTamanhoExp = 2,
        .blocosPorGrupo = 0,
        .inodosPorGrupo = 0,
        .gruposQuantidade = 0,
        .magic = 0xEF53,
        .estado = 1,
        .flags = 0,
        .verificacao = 0,
    };
    estadoExt4.superbloco = superblocoTemp;
}

fn validaMagic() void {
    if (estadoExt4.superbloco.magic != 0xEF53) {
        travaSistema();
    }
}

fn travaSistema() noreturn {
    while (true) {}
}
