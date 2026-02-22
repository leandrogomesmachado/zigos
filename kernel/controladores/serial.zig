const std = @import("std");

const enderecoBase: usize = 0x09000000;
const uartDr: *volatile u32 = @ptrFromInt(enderecoBase + 0x00);
const uartFr: *volatile u32 = @ptrFromInt(enderecoBase + 0x18);

pub fn inicializaConsole() void {
    configuraRegistros();
    escreveMensagem("console iniciado\n");
}

pub fn escreveMensagem(mensagem: []const u8) void {
    for (mensagem) |byte| {
        escreveByte(byte);
    }
}

fn escreveByte(byte: u8) void {
    aguardaBuffer();
    uartDr.* = byte;
}

fn aguardaBuffer() void {
    while ((uartFr.* & 0x20) != 0) {}
}

fn configuraRegistros() void {
    std.mem.doNotOptimizeAway(uartDr);
}

pub fn leByteDisponivel() ?u8 {
    const flags = uartFr.*;
    if ((flags & 0x10) != 0) {
        return null;
    }
    const valor = uartDr.*;
    return @truncate(u8, valor);
}

pub fn imprimePrompt() void {
    escreveMensagem("> ");
}

pub fn escreveByteUnitario(byte: u8) void {
    escreveByte(byte);
}
