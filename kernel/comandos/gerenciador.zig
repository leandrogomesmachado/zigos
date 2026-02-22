const std = @import("std");
const console = @import("../controladores/serial.zig");
const ext4 = @import("../fs/ext4Leitor.zig");
const bloco = @import("../controladores/dispositivoBloco.zig");

var bufferEntrada: [128]u8 = undefined;
var tamanhoEntrada: usize = 0;

const caractereNovaLinha: u8 = 0x0A;
const caractereRetornoCarro: u8 = 0x0D;
const caractereBackspace: u8 = 0x08;
const caractereDelete: u8 = 0x7F;

pub fn iniciaComandos() void {
    console.escreveMensagem("console comandos pronto\n");
    console.imprimePrompt();
}

pub fn executaComando(entrada: []const u8) void {
    const comando = normalizaEntrada(entrada);
    if (comando.len == 0) {
        return;
    }
    if (std.mem.eql(u8, comando, "limpa")) {
        comandoLimpa();
        return;
    }
    if (std.mem.eql(u8, comando, "lista")) {
        comandoLista();
        return;
    }
    if (std.mem.eql(u8, comando, "mostra")) {
        comandoMostra();
        return;
    }
    if (std.mem.eql(u8, comando, "reinicia")) {
        comandoReinicia();
        return;
    }
    if (std.mem.eql(u8, comando, "desliga")) {
        comandoDesliga();
        return;
    }
    comandoInvalido(comando);
}

pub fn executaSequencia(comandos: []const []const u8) void {
    var indice: usize = 0;
    while (indice < comandos.len) : (indice += 1) {
        executaComando(comandos[indice]);
    }
}

pub fn processaByte(byte: u8) void {
    if (byte == caractereNovaLinha or byte == caractereRetornoCarro) {
        console.escreveMensagem("\n");
        executaComando(bufferEntrada[0..tamanhoEntrada]);
        limpaEntrada();
        console.imprimePrompt();
        return;
    }
    if (byte == caractereBackspace or byte == caractereDelete) {
        trataBackspace();
        return;
    }
    if (tamanhoEntrada >= bufferEntrada.len) {
        return;
    }
    bufferEntrada[tamanhoEntrada] = byte;
    tamanhoEntrada += 1;
    console.escreveByteUnitario(byte);
}

pub fn varreduraSerial() void {
    while (true) {
        const byteOpcional = console.leByteDisponivel();
        if (byteOpcional == null) {
            return;
        }
        processaByte(byteOpcional.?);
    }
}

fn normalizaEntrada(entrada: []const u8) []const u8 {
    return std.mem.trim(u8, entrada, " \t\r\n");
}

fn comandoLimpa() void {
    console.escreveMensagem("\x1b[2J\x1b[H");
}

fn comandoLista() void {
    const resultado = ext4.percorreRaiz(listaVisitante) catch |erro| {
        trataErroExt4(erro);
        return;
    };
    _ = resultado;
}

fn comandoMostra() void {
    const talvezSuper = ext4.superblocoAtual();
    if (talvezSuper) |super| {
        imprimeResumo(super);
        return;
    }
    console.escreveMensagem("ext4 indisponivel\n");
}

fn comandoReinicia() void {
    console.escreveMensagem("reiniciando sistema\n");
    reiniciaSistema();
}

fn comandoDesliga() void {
    console.escreveMensagem("desligando sistema\n");
    desligaSistema();
}

fn comandoInvalido(comando: []const u8) void {
    console.escreveMensagem("comando invalido: ");
    console.escreveMensagem(comando);
    console.escreveMensagem("\n");
}

fn listaVisitante(nome: []const u8) void {
    console.escreveMensagem("- ");
    console.escreveMensagem(nome);
    console.escreveMensagem("\n");
}

fn imprimeResumo(super: ext4.Superbloco) void {
    var buffer: [128]u8 = undefined;
    var escritor = std.io.fixedBufferStream(&buffer);
    const saida = escritor.writer();
    _ = saida.print(
        "blocos={d} inodos={d} blocoTam={d}\n",
        .{
            super.blocosQuantidade,
            super.inodesQuantidade,
            calculaTam(super),
        },
    ) catch {
        console.escreveMensagem("resumo indisponivel\n");
        return;
    };
    console.escreveMensagem(escritor.getWritten());
}

fn calculaTam(super: ext4.Superbloco) usize {
    const base: usize = 1024;
    return base << @intCast(u6, super.blocoTamanhoExp & 0x3F);
}

fn reiniciaSistema() noreturn {
    while (true) {}
}

fn desligaSistema() noreturn {
    while (true) {}
}

fn limpaEntrada() void {
    tamanhoEntrada = 0;
}

fn trataBackspace() void {
    if (tamanhoEntrada == 0) {
        return;
    }
    tamanhoEntrada -= 1;
    console.escreveMensagem("\x08 \x08");
}

fn trataErroExt4(erro: anyerror) void {
    if (erro == ext4.ErroExt4.DispositivoIndisponivel) {
        console.escreveMensagem("ext4 sem dispositivo\n");
        return;
    }
    if (erro == ext4.ErroExt4.BlocoTamanhoIncompativel) {
        console.escreveMensagem("bloco ext4 incompativel\n");
        return;
    }
    if (erro == ext4.ErroExt4.BufferInsuficiente) {
        console.escreveMensagem("buffer ext4 insuficiente\n");
        return;
    }
    if (erro == ext4.ErroExt4.MagicInvalido) {
        console.escreveMensagem("ext4 magic invalido\n");
        return;
    }
    if (erro == ext4.ErroExt4.GrupoIndisponivel) {
        console.escreveMensagem("grupo ext4 indisponivel\n");
        return;
    }
    if (erro == ext4.ErroExt4.InodoForaDoLimite) {
        console.escreveMensagem("inodo fora do limite\n");
        return;
    }
    if (erro == bloco.ErroDispositivo.DispositivoNaoInicializado) {
        console.escreveMensagem("dispositivo nao inicializado\n");
        return;
    }
    if (erro == bloco.ErroDispositivo.BlocoInvalido) {
        console.escreveMensagem("bloco invalido\n");
        return;
    }
    if (erro == bloco.ErroDispositivo.LeituraForaDoLimite) {
        console.escreveMensagem("leitura fora do limite\n");
        return;
    }
    console.escreveMensagem("erro ext4 desconhecido\n");
}
