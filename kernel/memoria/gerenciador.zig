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

pub const AtributosMmu = struct {
    escrita: bool = true,
    executavel: bool = false,
    usuario: bool = false,
    dispositivo: bool = false,
};

pub const IntervaloMemoria = struct {
    inicio: u64,
    fim: u64,
    atributos: AtributosMmu,
};

pub const EstatisticaMemoria = struct {
    blocosMapeados: usize,
    tabelasNivel2Ativas: usize,
};

const paginaTamanho: usize = 0x1000;
const entradasPorTabela = 512;
const blocoNivel2Tamanho: u64 = 0x200000;
const maxTabelasNivel2 = 16;

const TabelaNivel2 = struct {
    usada: bool = false,
    indiceL1: usize = 0,
    dados: [entradasPorTabela]u64 align(paginaTamanho) = [_]u64{0} ** entradasPorTabela,
};

var contextoMemoria = ContextoMemoria{};
var tabelaNivel1: [entradasPorTabela]u64 align(paginaTamanho) = [_]u64{0} ** entradasPorTabela;
var tabelasNivel2 = [_]TabelaNivel2{TabelaNivel2{}} ** maxTabelasNivel2;
var mapaNivel2: [entradasPorTabela]?*TabelaNivel2 = [_]?*TabelaNivel2{null} ** entradasPorTabela;
var blocosMapeados: usize = 0;

pub fn inicializaMemoria(parametros: ParametrosMemoria) void {
    atualizaContexto(parametros);
    limpaAreaInicial();
    preparaTabelas();
    mapeiaPadroes();
    aplicaTabelas();
}

pub fn registraIntervalos(intervalos: []const IntervaloMemoria) void {
    var indice: usize = 0;
    while (indice < intervalos.len) : (indice += 1) {
        mapeiaIntervalo(intervalos[indice]);
    }
}

pub fn estatistica() EstatisticaMemoria {
    return EstatisticaMemoria{
        .blocosMapeados = blocosMapeados,
        .tabelasNivel2Ativas = contaTabelasAtivas(),
    };
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

fn preparaTabelas() void {
    std.mem.set(u64, tabelaNivel1[0..], 0);
    var indice: usize = 0;
    while (indice < tabelasNivel2.len) : (indice += 1) {
        tabelasNivel2[indice].usada = false;
        tabelasNivel2[indice].indiceL1 = 0;
        std.mem.set(u64, tabelasNivel2[indice].dados[0..], 0);
    }
    std.mem.set(?*TabelaNivel2, mapaNivel2[0..], null);
    blocosMapeados = 0;
}

fn mapeiaPadroes() void {
    const normal = atributosMemoriaNormal();
    const dispositivo = atributosDispositivo();
    const intervalos = [_]IntervaloMemoria{
        IntervaloMemoria{
            .inicio = 0x00000000,
            .fim = 0x40000000,
            .atributos = normal,
        },
        IntervaloMemoria{
            .inicio = 0x08000000,
            .fim = 0x09010000,
            .atributos = dispositivo,
        },
    };
    registraIntervalos(intervalos[0..]);
}

fn mapeiaIntervalo(intervalo: IntervaloMemoria) void {
    if (intervalo.fim <= intervalo.inicio) {
        return;
    }
    var endereco = intervalo.inicio & ~(@as(u64, blocoNivel2Tamanho) - 1);
    const limite = alinhadoSuperior(intervalo.fim);
    while (endereco < limite) {
        const indiceL1 = @intCast(usize, (endereco >> 30) & 0x1FF);
        const tabela = garanteTabelaNivel2(indiceL1);
        if (tabela == null) {
            return;
        }
        const indiceL2 = @intCast(usize, (endereco >> 21) & 0x1FF);
        tabela.?.dados[indiceL2] = criaEntradaBloco(endereco, intervalo.atributos);
        blocosMapeados += 1;
        contextoMemoria.paginasConfiguradas += 1;
        endereco += blocoNivel2Tamanho;
    }
}

fn garanteTabelaNivel2(indiceL1: usize) ?*TabelaNivel2 {
    const atual = mapaNivel2[indiceL1];
    if (atual != null) {
        return atual.?;
    }
    var indice: usize = 0;
    while (indice < tabelasNivel2.len) : (indice += 1) {
        if (!tabelasNivel2[indice].usada) {
            tabelasNivel2[indice].usada = true;
            tabelasNivel2[indice].indiceL1 = indiceL1;
            std.mem.set(u64, tabelasNivel2[indice].dados[0..], 0);
            const base = @intFromPtr(&tabelasNivel2[indice].dados);
            tabelaNivel1[indiceL1] = (base & mascaraTabela()) | 0b11;
            mapaNivel2[indiceL1] = &tabelasNivel2[indice];
            return &tabelasNivel2[indice];
        }
    }
    return null;
}

fn mascaraTabela() u64 {
    return ~(@as(u64, paginaTamanho) - 1);
}

fn criaEntradaBloco(base: u64, atributos: AtributosMmu) u64 {
    const alinhado = base & ~(@as(u64, blocoNivel2Tamanho) - 1);
    var valor = alinhado;
    valor |= 0b01;
    valor |= atributosParaBits(atributos);
    return valor;
}

fn atributosParaBits(atributos: AtributosMmu) u64 {
    var resultado: u64 = 0;
    resultado |= @as(u64, 1) << 10;
    resultado |= @as(u64, 0b11) << 8;
    var indice: u64 = 0;
    if (atributos.dispositivo) {
        indice = 1;
    }
    resultado |= indice << 2;
    if (!atributos.escrita) {
        resultado |= @as(u64, 0b01) << 6;
    }
    if (atributos.usuario) {
        resultado |= @as(u64, 0b10) << 6;
    }
    if (!atributos.executavel) {
        resultado |= @as(u64, 1) << 54;
        resultado |= @as(u64, 1) << 53;
    }
    return resultado;
}

fn atributosMemoriaNormal() AtributosMmu {
    return AtributosMmu{};
}

fn atributosDispositivo() AtributosMmu {
    return AtributosMmu{
        .escrita = true,
        .executavel = false,
        .usuario = false,
        .dispositivo = true,
    };
}

fn aplicaTabelas() void {
    const mairValor: u64 = 0xFF;
    const t0sz: u64 = 16;
    const tcrValor: u64 =
        t0sz |
        (@as(u64, 0b01) << 8) |
        (@as(u64, 0b01) << 10) |
        (@as(u64, 0b11) << 12) |
        (@as(u64, 0b00) << 14);
    const ttbrValor: u64 = @intFromPtr(&tabelaNivel1);

    asm volatile ("msr mair_el1, %[valor]"
        :: [valor] "r" (mairValor)
        : "memory");
    asm volatile ("msr tcr_el1, %[valor]"
        :: [valor] "r" (tcrValor)
        : "memory");
    asm volatile ("msr ttbr0_el1, %[valor]"
        :: [valor] "r" (ttbrValor)
        : "memory");
    barreirasSistema();
    habilitaMmu();
}

fn barreirasSistema() void {
    asm volatile ("dsb ish");
    asm volatile ("isb");
}

fn habilitaMmu() void {
    const controle: u64 = (@as(u64, 1) << 0) | (@as(u64, 1) << 2) | (@as(u64, 1) << 12);
    asm volatile ("msr sctlr_el1, %[valor]"
        :: [valor] "r" (controle)
        : "memory");
    asm volatile ("isb");
}

fn alinhadoSuperior(valor: u64) u64 {
    const mascara = blocoNivel2Tamanho - 1;
    if ((valor & mascara) == 0) {
        return valor;
    }
    return (valor & ~mascara) + blocoNivel2Tamanho;
}

fn contaTabelasAtivas() usize {
    var contador: usize = 0;
    var indice: usize = 0;
    while (indice < tabelasNivel2.len) : (indice += 1) {
        if (tabelasNivel2[indice].usada) {
            contador += 1;
        }
    }
    return contador;
}
