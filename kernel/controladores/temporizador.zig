const console = @import("serial.zig");

pub const HandlerTemporizador = fn() void;

var intervaloAtual: u64 = 0;
var handlerRegistrado: ?HandlerTemporizador = null;

pub fn iniciaTemporizador(intervalo: u64) void {
    if (intervalo == 0) {
        return;
    }
    intervaloAtual = intervalo;
    configuraIntervalo(intervaloAtual);
    habilitaContador();
    console.escreveMensagem("temporizador habilitado\n");
}

pub fn pausaTemporizador() void {
    desabilitaContador();
    console.escreveMensagem("temporizador pausado\n");
}

pub fn registraHandler(funcao: HandlerTemporizador) void {
    handlerRegistrado = funcao;
}

pub fn trataInterrupcao() void {
    rearmaInterrupcao();
    const atual = handlerRegistrado;
    if (atual == null) {
        return;
    }
    atual.?();
}

fn rearmaInterrupcao() void {
    if (intervaloAtual == 0) {
        return;
    }
    configuraIntervalo(intervaloAtual);
}

fn configuraIntervalo(valor: u64) void {
    asm volatile ("msr cntp_tval_el0, %[intervalo]"
        :
        : [intervalo] "r" (valor)
        : "memory");
}

fn habilitaContador() void {
    const flag: u64 = 1;
    asm volatile ("msr cntp_ctl_el0, %[controle]"
        :
        : [controle] "r" (flag)
        : "memory");
    sincroniza();
}

fn desabilitaContador() void {
    const flag: u64 = 0;
    asm volatile ("msr cntp_ctl_el0, %[controle]"
        :
        : [controle] "r" (flag)
        : "memory");
    sincroniza();
}

fn sincroniza() void {
    asm volatile ("isb");
}
