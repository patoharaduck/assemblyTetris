.data
.align 4

board:
    .zero 200

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

// select用タイムアウト構造体 {秒, マイクロ秒}
timeout:
    .quad 0        // tv_sec  = 0秒
    .quad 500000   // tv_usec = 500000μs = 0.5秒

input_buf:
    .byte 0

.text
.global _main
.align 2

_main:
    stp x29, x30, [sp, #-16]!

    // termios取得
    mov x0, #0
    adrp x1, termios_orig@PAGE
    add x1, x1, termios_orig@PAGEOFF
    bl _tcgetattr

    // コピー
    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    adrp x1, termios_orig@PAGE
    add x1, x1, termios_orig@PAGEOFF
    mov x2, #72
    bl _memcpy

    // c_lflag: ECHO・ICANON を落とす (offset 24)
    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    ldr w1, [x0, #24]
    mov w2, #0x108
    bic w1, w1, w2
    str w1, [x0, #24]

    // VMIN=0, VTIME=0 (offset 48, 49)
    mov w3, #0
    strb w3, [x0, #48]
    strb w3, [x0, #49]

    // 設定反映
    mov x0, #0
    mov x1, #0
    adrp x2, termios_new@PAGE
    add x2, x2, termios_new@PAGEOFF
    bl _tcsetattr

    mov w20, #4

game_loop:
    // 1. 画面クリア
    mov x0, #1
    adrp x1, clear_screen@PAGE
    add x1, x1, clear_screen@PAGEOFF
    mov x2, #7
    mov x16, #4
    svc #0x80

    // 2. ボードリセット
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    mov w1, #0
    mov w2, #0
clear_board:
    strb w1, [x0, w2, uxtw]
    add w2, w2, #1
    cmp w2, #200
    b.lt clear_board

    // 3. 現在位置に1をセット
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    mov w1, #1
    strb w1, [x0, w20, uxtw]

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

    // 5. selectで最大0.5秒待ちつつキー入力受付
    // fd_set をスタックに確保（128バイト）してゼロクリア
    sub sp, sp, #128
    mov x0, sp
    mov x1, #0
    mov x2, #128
    bl _memset

    // fd_set にfd=0をセット (ビット0を立てる)
    mov w1, #1
    str w1, [sp]

    // timeoutを毎回リセット（selectが書き換えるため）
    adrp x0, timeout@PAGE
    add x0, x0, timeout@PAGEOFF
    mov x1, #0
    str x1, [x0]           // tv_sec = 0
    mov x1, #33920
    movk x1, #7, lsl #16

    // select(1, &fd_set, NULL, NULL, &timeout)
    mov x0, #1             // nfds
    mov x1, sp             // readfds
    mov x2, #0             // writefds
    mov x3, #0             // exceptfds
    adrp x4, timeout@PAGE
    add x4, x4, timeout@PAGEOFF
    mov x16, #93           // select syscall
    svc #0x80

    // スタック復元
    add sp, sp, #128

    // x0 > 0 ならキーあり
    cmp x0, #0
    b.le do_fall           // タイムアウト→そのまま落下

    // キー読み込み
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
    add w20, w20, #10
    cmp w20, #200
    b.lt game_loop
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
