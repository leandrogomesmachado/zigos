const std = @import("std");
const bloco = @import("../controladores/dispositivoBloco.zig");

pub const ParametrosExt4 = struct {
    blocoTamanho: usize = 4096,
};

pub const ErroExt4 = error{
    DispositivoIndisponivel,
    BlocoTamanhoIncompativel,
    BufferInsuficiente,
    MagicInvalido,
    GrupoIndisponivel,
    InodoForaDoLimite,
};

pub const Superbloco = extern struct {
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
    montagens: u16,
    maxMontagens: u16,
    revisao: u32,
    idGeracao: u32,
    primeiroInodoNaoReservado: u32,
    inodoTamanho: u16,
    blocoGrupo: u16,
};

pub const DescriptorGrupo = extern struct {
    blocoBitmap: u32,
    inodoBitmap: u32,
    blocoTabelaInodo: u32,
    blocosLivres: u16,
    inodosLivres: u16,
    diretoriosUsados: u16,
    padding: u16,
    reservados: [3]u32,
};

pub const Inodo = extern struct {
    modo: u16,
    uid: u16,
    tamanhoLow: u32,
    tempoAcesso: u32,
    tempoCriacao: u32,
    tempoModificacao: u32,
    tempoExclusao: u32,
    gid: u16,
    links: u16,
    setoresUsados: u32,
    flags: u32,
    oss: u32,
    blocosDiretos: [12]u32,
    blocoIndiretoSimples: u32,
    blocoIndiretoDuplo: u32,
    blocoIndiretoTriplo: u32,
    geracao: u32,
    arquivoAcl: u32,
    tamanhoHigh: u32,
    fragmento: u32,
};

const DirEntry = extern struct {
    inode: u32,
    rec_len: u16,
    name_len: u8,
    tipo: u8,
};

const offsetSuperbloco = 1024;
const bufferMaximo = 4096;

const EstadoExt4 = struct {
    parametros: ParametrosExt4,
    superbloco: Superbloco,
    grupoPrincipal: DescriptorGrupo,
    ativo: bool,
};

var estadoExt4 = EstadoExt4{
    .parametros = ParametrosExt4{},
    .superbloco = undefined,
    .grupoPrincipal = undefined,
    .ativo = false,
};

var blocoTemporarioInterno: [bufferMaximo]u8 = undefined;

pub fn inicializaLeitor(parametros: ParametrosExt4) ErroExt4!void {
    estadoExt4.parametros = parametros;
    try garanteBuffer();
    const config = try garanteDispositivo(parametros);
    try carregaSuperbloco();
    validaMagic();
    try validaBloco(config);
    try carregaDescritorGrupo();
    estadoExt4.ativo = true;
}

pub fn superblocoAtual() ?Superbloco {
    if (!estadoExt4.ativo) {
        return null;
    }
    return estadoExt4.superbloco;
}

pub fn percorreRaiz(visitante: fn([]const u8) void) (ErroExt4 || bloco.ErroDispositivo)!void {
    if (!estadoExt4.ativo) {
        return ErroExt4.DispositivoIndisponivel;
    }
    const inodoRaiz = try lerInodo(2);
    try percorreDiretorio(inodoRaiz, visitante);
}

pub fn lerBloco(indice: u32, destino: []u8) (ErroExt4 || bloco.ErroDispositivo)!void {
    const esperado = estadoExt4.parametros.blocoTamanho;
    if (destino.len != esperado) {
        return ErroExt4.BufferInsuficiente;
    }
    try bloco.leBloco(@as(usize, indice), destino);
}

pub fn lerInodo(indice: u32) (ErroExt4 || bloco.ErroDispositivo)!Inodo {
    if (!estadoExt4.ativo) {
        return ErroExt4.DispositivoIndisponivel;
    }
    if (indice == 0) {
        return ErroExt4.InodoForaDoLimite;
    }
    if (indice > estadoExt4.superbloco.inodesQuantidade) {
        return ErroExt4.InodoForaDoLimite;
    }
    const porGrupo = estadoExt4.superbloco.inodosPorGrupo;
    if (porGrupo == 0) {
        return ErroExt4.InodoForaDoLimite;
    }
    const zeroBased = indice - 1;
    const grupo = zeroBased / porGrupo;
    if (grupo != 0) {
        return ErroExt4.GrupoIndisponivel;
    }
    const indiceLocal = zeroBased % porGrupo;
    const tamanhoInodo = estadoExt4.superbloco.inodoTamanho;
    if (tamanhoInodo < @sizeOf(Inodo)) {
        return ErroExt4.BufferInsuficiente;
    }
    const blocosPorInodo = estadoExt4.parametros.blocoTamanho / tamanhoInodo;
    if (blocosPorInodo == 0) {
        return ErroExt4.BufferInsuficiente;
    }
    const blocoTabela = estadoExt4.grupoPrincipal.blocoTabelaInodo;
    const blocoIndice = blocoTabela + @intCast(u32, indiceLocal / blocosPorInodo);
    var buffer = blocoTemporario();
    try bloco.leBloco(@as(usize, blocoIndice), buffer);
    const deslocamento = (indiceLocal % blocosPorInodo) * tamanhoInodo;
    const fim = deslocamento + @as(usize, @sizeOf(Inodo));
    if (fim > buffer.len) {
        return ErroExt4.BufferInsuficiente;
    }
    const fatia = buffer[deslocamento..fim];
    return std.mem.bytesToValue(Inodo, fatia);
}

fn garanteBuffer() ErroExt4!void {
    if (estadoExt4.parametros.blocoTamanho > bufferMaximo) {
        return ErroExt4.BufferInsuficiente;
    }
}

fn blocoTemporario() []u8 {
    return blocoTemporarioInterno[0..estadoExt4.parametros.blocoTamanho];
}

fn garanteDispositivo(parametros: ParametrosExt4) ErroExt4!bloco.ConfiguracaoDispositivo {
    const atual = bloco.configuracaoAtual();
    if (atual == null) {
        return ErroExt4.DispositivoIndisponivel;
    }
    const config = atual.?;
    if (config.blocoTamanho != parametros.blocoTamanho) {
        return ErroExt4.BlocoTamanhoIncompativel;
    }
    return config;
}

fn carregaSuperbloco() (ErroExt4 || bloco.ErroDispositivo)!void {
    var buffer = blocoTemporario();
    try bloco.leBloco(0, buffer);
    const inicio = offsetSuperbloco;
    const fim = inicio + @sizeOf(Superbloco);
    if (fim > buffer.len) {
        return ErroExt4.BufferInsuficiente;
    }
    estadoExt4.superbloco = std.mem.bytesToValue(Superbloco, buffer[inicio..fim]);
}

fn validaMagic() void {
    if (estadoExt4.superbloco.magic != 0xEF53) {
        travaSistema();
    }
}

fn validaBloco(config: bloco.ConfiguracaoDispositivo) ErroExt4!void {
    const calculado = calculaBlocoSuperbloco();
    if (calculado != estadoExt4.parametros.blocoTamanho) {
        return ErroExt4.BlocoTamanhoIncompativel;
    }
    if (config.blocoTamanho != estadoExt4.parametros.blocoTamanho) {
        return ErroExt4.BlocoTamanhoIncompativel;
    }
}

fn carregaDescritorGrupo() (ErroExt4 || bloco.ErroDispositivo)!void {
    var buffer = blocoTemporario();
    try bloco.leBloco(1, buffer);
    const bytes = buffer[0..@sizeOf(DescriptorGrupo)];
    estadoExt4.grupoPrincipal = std.mem.bytesToValue(DescriptorGrupo, bytes);
}

fn calculaBlocoSuperbloco() usize {
    const exp = estadoExt4.superbloco.blocoTamanhoExp;
    const base: usize = 1024;
    return base << exp;
}

fn percorreDiretorio(inodo: Inodo, visitante: fn([]const u8) void) (ErroExt4 || bloco.ErroDispositivo)!void {
    var indice: usize = 0;
    while (indice < inodo.blocosDiretos.len) : (indice += 1) {
        const identificador = inodo.blocosDiretos[indice];
        if (identificador == 0) {
            continue;
        }
        var buffer = blocoTemporario();
        try bloco.leBloco(@as(usize, identificador), buffer);
        percorreEntradas(buffer, visitante);
    }
}

fn percorreEntradas(buffer: []u8, visitante: fn([]const u8) void) void {
    var deslocamento: usize = 0;
    while (deslocamento + @sizeOf(DirEntry) <= buffer.len) {
        const entrada = std.mem.bytesToValue(DirEntry, buffer[deslocamento .. deslocamento + @sizeOf(DirEntry)]);
        const tamanhoRegistro = @as(usize, entrada.rec_len);
        if (tamanhoRegistro < @sizeOf(DirEntry)) {
            return;
        }
        if (deslocamento + tamanhoRegistro > buffer.len) {
            return;
        }
        if (entrada.inode != 0) {
            processaEntrada(entrada, buffer[deslocamento .. deslocamento + entrada.rec_len], visitante);
        }
        deslocamento += entrada.rec_len;
    }
}

fn processaEntrada(entrada: DirEntry, registro: []const u8, visitante: fn([]const u8) void) void {
    if (entrada.name_len == 0) {
        return;
    }
    if (!entradaValida(entrada)) {
        return;
    }
    const inicioNome = @sizeOf(DirEntry);
    const fimNome = inicioNome + entrada.name_len;
    if (fimNome > registro.len) {
        return;
    }
    var nomeTemp: [256]u8 = undefined;
    const destino = nomeTemp[0..entrada.name_len];
    std.mem.copy(u8, destino, registro[inicioNome..fimNome]);
    visitante(destino);
}

fn entradaValida(entrada: DirEntry) bool {
    if (entrada.name_len == 1 and registroIgual(entrada.tipo, 0)) {
        return true;
    }
    return nomeVisivel(entrada);
}

fn nomeVisivel(entrada: DirEntry) bool {
    if (entrada.name_len == 1) {
        return registroIgual(entrada.tipo, 0);
    }
    if (entrada.name_len == 2) {
        return true;
    }
    return true;
}

fn registroIgual(tipo: u8, esperado: u8) bool {
    if (tipo == esperado) {
        return true;
    }
    return false;
}

fn travaSistema() noreturn {
    while (true) {}
}
