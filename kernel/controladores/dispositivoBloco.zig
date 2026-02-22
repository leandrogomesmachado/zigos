const std = @import("std");

pub const ConfiguracaoDispositivo = struct {
    enderecoBase: [*]u8,
    tamanhoTotal: usize,
    blocoTamanho: usize,
};

pub const ErroDispositivo = error{
    DispositivoNaoInicializado,
    BlocoInvalido,
    LeituraForaDoLimite,
};

var dispositivoAtivo: ?ConfiguracaoDispositivo = null;

pub fn inicializaDispositivo(config: ConfiguracaoDispositivo) void {
    if (config.blocoTamanho == 0) {
        return;
    }
    dispositivoAtivo = config;
}

pub fn configuracaoAtual() ?ConfiguracaoDispositivo {
    return dispositivoAtivo;
}

pub fn leBloco(indice: usize, destino: []u8) ErroDispositivo!void {
    const atual = dispositivoAtivo;
    if (atual == null) {
        return ErroDispositivo.DispositivoNaoInicializado;
    }
    var configuracao = atual.?;
    if (destino.len != configuracao.blocoTamanho) {
        return ErroDispositivo.BlocoInvalido;
    }
    const deslocamento = indice * configuracao.blocoTamanho;
    const limite = deslocamento + destino.len;
    if (limite > configuracao.tamanhoTotal) {
        return ErroDispositivo.LeituraForaDoLimite;
    }
    const enderecoInteiro = @intFromPtr(configuracao.enderecoBase);
    const origemInteiro = enderecoInteiro + deslocamento;
    const origem = @as([*]const u8, @ptrFromInt(origemInteiro));
    const origemSlice = origem[0..destino.len];
    std.mem.copy(u8, destino, origemSlice);
}
