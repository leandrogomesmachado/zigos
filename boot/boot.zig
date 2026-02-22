const kernel = @import("../kernel/main.zig");

pub const IntervaloBss = struct {
    inicio: [*]u8,
    fim: [*]u8,
};

pub export fn bootJump() callconv(.C) noreturn {
    var intervaloPadrao = IntervaloBss{
        .inicio = ponteiroNulo(),
        .fim = ponteiroNulo(),
    };
    limpaBss(intervaloPadrao);
    var contexto = kernel.ContextoKernel{};
    kernel.kernelMain(&contexto);
}

fn ponteiroNulo() [*]u8 {
    return @as([*]u8, @ptrFromInt(0));
}

fn limpaBss(intervalo: IntervaloBss) void {
    const inicioValor = @intFromPtr(intervalo.inicio);
    const fimValor = @intFromPtr(intervalo.fim);
    if (fimValor <= inicioValor) {
        return;
    }
    const tamanho = fimValor - inicioValor;
    const fatia = intervalo.inicio[0..tamanho];
    @memset(fatia, 0);
}
