const console = @import("../controladores/serial.zig");

pub const Tarefa = struct {
    identificador: u32,
    descricao: []const u8,
};

var tarefasRegistradas: [16]?Tarefa = [_]?Tarefa{null} ** 16;
var tarefasAtivas: usize = 0;

pub fn registraTarefa(tarefa: Tarefa) void {
    if (tarefasAtivas >= tarefasRegistradas.len) {
        return;
    }
    tarefasRegistradas[tarefasAtivas] = tarefa;
    tarefasAtivas += 1;
}

pub fn iniciaEscalonador() void {
    console.escreveMensagem("escalonador ativo\n");
}
