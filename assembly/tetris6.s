.data
.align 4

board:
    .zero 200

fixed_board:
    .zero 200

// 各ミノの4マスのオフセット（7種類 × 4マス）
mino_data:
    // I
    .word 0, 1, 2, 3
    // O
    .word 0, 1, 10, 11
    // T
    .word 0, 1, 2, 11
    // S
    .word 1, 2, 10, 11
    // Z
    .word 0, 1, 11, 12
    // J
    .word 0, 10, 11, 12
    // L
    .word 2, 10, 11, 12

current_type:
    .word 0         // 現在のミノ種類(0-6)

msg_block:
    .ascii "X"
msg_dot:
    .ascii "."
msg_newline:
    .ascii "\n"
clear_screen:
    .ascii "\033[H\033[J"

.align 8
termios_orig:
    .zero 72
termios_new:
    .zero 72

timeout:
    .quad 0
    .quad 500000

input_buf:
    .byte 0

.text
.global _main
.align 2

_main:
    stp x29, x30, [sp, #-16]!

    mov x0, #0
    adrp x1, termios_orig@PAGE
    add x1, x1, termios_orig@PAGEOFF
    bl _tcgetattr

    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    adrp x1, termios_orig@PAGE
    add x1, x1, termios_orig@PAGEOFF
    mov x2, #72
    bl _memcpy

    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    ldr w1, [x0, #24]
    mov w2, #0x108
    bic w1, w1, w2
    str w1, [x0, #24]

    mov w3, #0
    strb w3, [x0, #48]
    strb w3, [x0, #49]

    mov x0, #0
    mov x1, #0
    adrp x2, termios_new@PAGE
    add x2, x2, termios_new@PAGEOFF
    bl _tcsetattr

    mov w20, #4         // 現在位置
    mov w21, #0         // 現在のミノ種類

game_loop:
    // 1. 画面クリア
    mov x0, #1
    adrp x1, clear_screen@PAGE
    add x1, x1, clear_screen@PAGEOFF
    mov x2, #7
    mov x16, #4
    svc #0x80

    // 2. boardにfixed_boardをコピー
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    adrp x1, fixed_board@PAGE
    add x1, x1, fixed_board@PAGEOFF
    mov x2, #200
    bl _memcpy

    // 3. 現在のミノを4マス描画
    // mino_data[w21 * 4] からオフセットを4つ読む
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    mov w8, w21
    lsl w8, w8, #4          // *16 (4マス × 4バイト)
    add x9, x9, w8, uxtw    // ミノデータの先頭

    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF

    // マス1
    ldr w8, [x9, #0]
    add w8, w8, w20
    mov w1, #1
    strb w1, [x0, w8, uxtw]

    // マス2
    ldr w8, [x9, #4]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    // マス3
    ldr w8, [x9, #8]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    // マス4
    ldr w8, [x9, #12]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    // 4. 描画
    mov w10, #0
    mov w11, #10

draw_loop:
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    ldrb w6, [x0, w10, uxtw]
    cmp w6, #1
    b.eq print_x

print_dot:
    adrp x1, msg_dot@PAGE
    add x1, x1, msg_dot@PAGEOFF
    b do_print

print_x:
    adrp x1, msg_block@PAGE
    add x1, x1, msg_block@PAGEOFF

do_print:
    mov x0, #1
    mov x2, #1
    mov x16, #4
    svc #0x80

    sub w11, w11, #1
    cmp w11, #0
    b.ne next_step

    mov x0, #1
    adrp x1, msg_newline@PAGE
    add x1, x1, msg_newline@PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80
    mov w11, #10

next_step:
    add w10, w10, #1
    cmp w10, #200
    b.lt draw_loop

    // 5. selectで0.5秒待機
    sub sp, sp, #128
    mov x29, sp
    mov x0, sp
    mov x1, #0
    mov x2, #128
    bl _memset

    mov w1, #1
    str w1, [sp]

    adrp x0, timeout@PAGE
    add x0, x0, timeout@PAGEOFF
    mov x1, #0
    str x1, [x0]
    mov x1, #33920
    movk x1, #7, lsl #16
    str x1, [x0, #8]

    mov x0, #1
    mov x1, sp
    mov x2, #0
    mov x3, #0
    adrp x4, timeout@PAGE
    add x4, x4, timeout@PAGEOFF
    mov x16, #93
    svc #0x80

    add sp, sp, #128

    cmp x0, #0
    b.le do_fall

    mov x0, #0
    adrp x1, input_buf@PAGE
    add x1, x1, input_buf@PAGEOFF
    mov x2, #1
    mov x16, #3
    svc #0x80

    adrp x1, input_buf@PAGE
    add x1, x1, input_buf@PAGEOFF
    ldrb w7, [x1]

    cmp w7, #'q'
    b.eq quit_game
    cmp w7, #'a'
    b.eq move_left
    cmp w7, #'d'
    b.eq move_right
    b do_fall

move_left:
    mov w8, w20
    mov w9, #10
    udiv w6, w8, w9
    msub w6, w6, w9, w8
    cmp w6, #0
    b.eq do_fall
    sub w20, w20, #1
    b do_fall

move_right:
    mov w8, w20
    mov w9, #10
    udiv w6, w8, w9
    msub w6, w6, w9, w8
    cmp w6, #9
    b.eq do_fall
    add w20, w20, #1

do_fall:
    // ミノの4マス全ての一行下をチェック
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    mov w8, w21
    lsl w8, w8, #4
    add x9, x9, w8, uxtw

    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF

    // マス1チェック
    ldr w8, [x9, #0]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    // マス2チェック
    ldr w8, [x9, #4]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    // マス3チェック
    ldr w8, [x9, #8]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    // マス4チェック
    ldr w8, [x9, #12]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    // 問題なければ落下
    add w20, w20, #10
    b game_loop

fix_block:
    // 4マス全てをfixed_boardに書き込む
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    mov w8, w21
    lsl w8, w8, #4
    add x9, x9, w8, uxtw

    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF
    mov w1, #1

    ldr w8, [x9, #0]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    ldr w8, [x9, #4]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    ldr w8, [x9, #8]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    ldr w8, [x9, #12]
    add w8, w8, w20
    strb w1, [x0, w8, uxtw]

    // 次のミノ（順番に切り替え、0-6でループ）
    add w21, w21, #1
    cmp w21, #7
    b.lt next_mino
    mov w21, #0
next_mino:
    mov w20, #4
    b game_loop

quit_game:
    mov x0, #0
    mov x1, #0
    adrp x2, termios_orig@PAGE
    add x2, x2, termios_orig@PAGEOFF
    bl _tcsetattr

    ldp x29, x30, [sp], #16
    mov x0, #0
    mov x16, #1
    svc #0x80