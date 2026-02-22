# Kernel Zigos

Projeto de kernel ARM64 escrito em Zig e inspirado na simplicidade do README do kernel Linux. Objetivo central: fornecer base rapida, segura e totalmente em portugues brasileiro (sem acentos nos identificadores) para execucao bare-metal com suporte inicial a leitura ext4.

## Estado atual
- Boot strap minimalista em `boot/boot.zig` que limpa BSS e transfere controle para `kernelMain`.
- Subsistema de memoria inicial em `kernel/memoria/gerenciador.zig` com rotina de mapeamento identitario e limpeza basica de paginas.
- Console serial PL011 em `kernel/controladores/serial.zig` para logs de depuracao logo apos o boot.
- Esqueleto do leitor ext4 em `kernel/fs/ext4Leitor.zig`, validando magic e preparando futuras operacoes de bloco e inode.

## Requisitos
1. Zig >= 0.12 com suporte a target `aarch64-freestanding`.
2. QEMU-system-aarch64 para execucao e depuracao.
3. Ferramentas para gerar imagens ext4 (`mke2fs`, `debugfs`).
4. Powershell para rodar o script `runTests.ps1` (a ser criado) conforme passos descritos em `comando.txt`.

## Como compilar
```
zig build boot   # compila bootRom
zig build kernel # compila kernelImg
```
Os artefatos sao instalados em `zig-out/bin`. Ajuste o script de build conforme necessidades de firmware/bootloader.

## Como testar
1. Gere imagem ext4 vazia e injete os binarios seguindo `documentacao/comando.txt`.
2. Execute `zig build teste` (vai acionar `runTests.ps1`, que deve invocar QEMU com `-d guestErrors`).
3. Verifique saida serial para confirmar inicializacao de console, memoria e leitor ext4.

## Estrutura de diretorios
```
boot/                    # rotinas de inicializacao
kernel/main.zig          # ponto de entrada
kernel/memoria/          # gerenciamento de memoria
kernel/controladores/    # drivers (serial, etc.)
kernel/fs/               # leitores de sistemas de arquivos (ext4)
documentacao/            # guias, incluindo comando.txt e README.md
```

## Contribuicoes
- Manter nomes em portugues brasileiro sem acentos e em camelCase.
- Evitar uso de `else`, priorizando retornos antecipados e funcoes auxiliares.
- Toda documentacao adicional deve residir em `documentacao/` e estar em portugues brasileiro.

## Proximos passos
1. Completar script `runTests.ps1` para provisionar imagens e executar QEMU.
2. Evoluir leitor ext4 para leitura real de blocos/inodes.
3. Implementar escalonador basico e drivers adicionais (timer, interrupcoes, GPIO).
4. Expandir configuracao de MMU com tabelas completas e protecoes XN.
