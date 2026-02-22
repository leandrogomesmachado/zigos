const std = @import("std");

pub const ParametrosMemoria = struct {
    memoriaBase: u64 = 0,
    dtbEndereco: u64 = 0,
};

pub const ContextoMemoria = struct {
    memoriaBase: u64 = 0,
    dtbEndereco: u64 = 0,
    paginasConfiguradas: usize = 0,
};

const paginaTamanho: usize = 0x1000;
var contextoMemoria = ContextoMemoria{};

pub fn inicializaMemoria(parametros: ParametrosMemoria) void {
    atualizaContexto(parametros);
    limpaAreaInicial();
    configuraMmuBase();
}

pub fn mapaPagina(destino: u64, origem: u64, atributos: u64) void {
    if (!enderecosAlinhados(destino, origem)) {
        return;
    }
    aplicaMapa(destino, origem, atributos);
    contextoMemoria.paginasConfiguradas += 1;
}

pub fn limpaPagina(endereco: u64) void {
    if (endereco == 0) {
        return;
    }
    const ponteiro = @as([*]u8, @ptrFromInt(endereco));
    const fatia = ponteiro[0..paginaTamanho];
    @memset(fatia, 0);
}

pub fn contextoAtual() ContextoMemoria {
    return contextoMemoria;
}

fn atualizaContexto(parametros: ParametrosMemoria) void {
    contextoMemoria.memoriaBase = parametros.memoriaBase;
    contextoMemoria.dtbEndereco = parametros.dtbEndereco;
    contextoMemoria.paginasConfiguradas = 0;
}

fn limpaAreaInicial() void {
    if (contextoMemoria.memoriaBase == 0) {
        return;
    }
    const limite = contextoMemoria.memoriaBase + 0x10000;
    var endereco = contextoMemoria.memoriaBase;
    while (endereco < limite) {
        limpaPagina(endereco);
        endereco += @as(u64, paginaTamanho);
    }
}

fn configuraMmuBase() void {
    guardaRegistradores();
    carregaTabelaInicial();
    ativaMmu();
}

fn guardaRegistradores() void {
    std.mem.doNotOptimizeAway(contextoMemoria.memoriaBase);
}

fn carregaTabelaInicial() void {
    const destino = contextoMemoria.memoriaBase;
    mapaPagina(destino, destino, 0);
}

fn ativaMmu() void {
    asm volatile ("isb");
}

fn enderecosAlinhados(destino: u64, origem: u64) bool {
    const mascara = @as(u64, paginaTamanho - 1);
    if ((destino & mascara) != 0) {
        return false;
    }
    if ((origem & mascara) != 0) {
        return false;
    }
    return true;
}

fn aplicaMapa(destino: u64, origem: u64, atributos: u64) void {
    std.mem.doNotOptimizeAway(destino | origem | atributos);
}
