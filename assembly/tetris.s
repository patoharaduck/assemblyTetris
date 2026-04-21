.data
.align 4

board:
    .zero 200

fixed_board:
    .zero 200

// 各ミノ × 4回転 × 4マス
// 合計 7 * 4 * 4 = 112 words
mino_data:
    // I (回転0,1,2,3)
    .word 0, 1, 2, 3
    .word 0, 10, 20, 30
    .word 0, 1, 2, 3
    .word 0, 10, 20, 30

    // O
    .word 0, 1, 10, 11
    .word 0, 1, 10, 11
    .word 0, 1, 10, 11
    .word 0, 1, 10, 11

    // T
    .word 0, 1, 2, 11    // 回転0: XXX / .X.
    .word 0, 10, 11, 20  // 回転1: X. / XX / X.
    .word 1, 10, 11, 12  // 回転2: .X. / XXX
    .word 1, 10, 11, 21  // 回転3: .X / XX / .X  ← 修正

    // S
    .word 1, 2, 10, 11
    .word 0, 10, 11, 21
    .word 1, 2, 10, 11
    .word 0, 10, 11, 21

    // Z
    .word 0, 1, 11, 12
    .word 1, 10, 11, 20
    .word 0, 1, 11, 12
    .word 1, 10, 11, 20

    // J
    .word 0, 10, 11, 12  // 回転0: X. / XXX
    .word 0, 1, 10, 20   // 回転1: XX / X. / X.  ← J左向きはこれが正しい
    .word 0, 1, 2, 12    // 回転2: XXX / ..X
    .word 1, 11, 20, 21  // 回転3: .X / .X / XX

    // L
    .word 2, 10, 11, 12  // 上: ..X / XXX
    .word 0, 10, 20, 21  // 左: X. / X. / XX
    .word 0, 1, 2, 10    // 下: XXX / X..
    .word 0, 1, 11, 21   // 右: XX / .X / .X
current_type:
    .word 0
current_rot:
    .word 0

msg_block:
    .ascii "X"
msg_dot:
    .ascii "."
msg_newline:
    .ascii "\n"
msg_gameover:
    .ascii "GAME OVER\n"
msg_score:
    .ascii "Lines: "
score:
    .word 0
.align 4
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

    mov w20, #4     // 現在位置
    mov w21, #0     // ミノ種類
    mov w22, #0     // 回転状態

game_loop:
    mov x0, #1
    adrp x1, clear_screen@PAGE
    add x1, x1, clear_screen@PAGEOFF
    mov x2, #7
    mov x16, #4
    svc #0x80

    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    adrp x1, fixed_board@PAGE
    add x1, x1, fixed_board@PAGEOFF
    mov x2, #200
    bl _memcpy

    // ミノ描画
    // オフセット = (w21 * 4 + w22) * 16
    mov w8, w21
    lsl w8, w8, #2       // *4
    add w8, w8, w22      // + 回転
    lsl w8, w8, #4       // *16
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    add x9, x9, w8, uxtw

    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
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

    // 描画
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

    // select待機
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
    cmp w7, #'w'
    b.eq do_rotate
    b do_fall

// ===== 左移動 =====
move_left:
    // x9にミノデータのアドレスを取得（x9を壊さないようにw8だけ使う）
    mov w8, w21
    lsl w8, w8, #2
    add w8, w8, w22
    lsl w8, w8, #4
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    add x9, x9, w8, uxtw

    // 全4マスの列が0でないか確認（w9は使わずx9固定）
    mov w3, #10          // w3を除数に使う（w9は使わない）

    ldr w8, [x9, #0]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #0
    b.eq do_fall

    ldr w8, [x9, #4]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #0
    b.eq do_fall

    ldr w8, [x9, #8]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #0
    b.eq do_fall

    ldr w8, [x9, #12]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #0
    b.eq do_fall

    sub w20, w20, #1
    b do_fall

// ===== 右移動 =====
move_right:
    mov w8, w21
    lsl w8, w8, #2
    add w8, w8, w22
    lsl w8, w8, #4
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    add x9, x9, w8, uxtw

    mov w3, #10

    ldr w8, [x9, #0]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #9
    b.eq do_fall

    ldr w8, [x9, #4]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #9
    b.eq do_fall

    ldr w8, [x9, #8]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #9
    b.eq do_fall

    ldr w8, [x9, #12]
    add w8, w8, w20
    udiv w6, w8, w3
    msub w6, w6, w3, w8
    cmp w6, #9
    b.eq do_fall

    add w20, w20, #1
    b do_fall

// ===== 回転 =====
do_rotate:
    add w22, w22, #1
    cmp w22, #4
    b.lt do_fall
    mov w22, #0
    b do_fall

// ===== 落下チェック =====
do_fall:
    mov w8, w21
    lsl w8, w8, #2
    add w8, w8, w22
    lsl w8, w8, #4
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    add x9, x9, w8, uxtw

    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF

    ldr w8, [x9, #0]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    ldr w8, [x9, #4]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    ldr w8, [x9, #8]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    ldr w8, [x9, #12]
    add w8, w8, w20
    add w8, w8, #10
    cmp w8, #200
    b.ge fix_block
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq fix_block

    add w20, w20, #10
    b game_loop

// ===== 固定 =====
fix_block:
    mov w8, w21
    lsl w8, w8, #2
    add w8, w8, w22
    lsl w8, w8, #4
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
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

    add w21, w21, #1
    cmp w21, #7
    b.lt check_lines  // ← 常にcheck_linesへ
    mov w21, #0
    b check_lines     // ← w21リセット後もcheck_linesへ

// ===== ライン消去 =====
check_lines:
    mov w23, #19        // 下から確認（行19から0へ）

check_line_loop:
    cmp w23, #0
    b.lt set_next       // 全行チェック完了

    // この行の合計を数える
    mov w24, #0         // 列カウンタ
    mov w25, #0         // ブロック数

    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF

    // w23行のオフセット = w23 * 10
    mov w26, w23
    mov w3, #10
    mul w26, w26, w3    // w26 = 行の先頭インデックス

count_loop:
    ldrb w6, [x0, w26, uxtw]
    add w25, w25, w6    // ブロック数を足す
    add w26, w26, #1
    add w24, w24, #1
    cmp w24, #10
    b.lt count_loop

    // 10個揃っていたら消去
    cmp w25, #10
    b.eq erase_line

    // 揃っていなければ次の行へ
    sub w23, w23, #1
    b check_line_loop

erase_line:
    // w23行を消してその上を全部1行下にずらす
    // 行w23から行1まで、上の行をコピーしてくる
    mov w24, w23        // 現在消去行

shift_loop:
    cmp w24, #0
    b.eq clear_top_line // 行0まで来たらトップをクリア

    // w24行 = w24-1行のコピー
    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF

    sub w26, w24, #1    // 上の行
    mov w3, #10
    mul w26, w26, w3    // 上の行の先頭インデックス
    mul w27, w24, w3    // 現在行の先頭インデックス

    mov w4, #0          // 列カウンタ
copy_row:
    ldrb w6, [x0, w26, uxtw]
    strb w6, [x0, w27, uxtw]
    add w26, w26, #1
    add w27, w27, #1
    add w4, w4, #1
    cmp w4, #10
    b.lt copy_row

    sub w24, w24, #1
    b shift_loop

clear_top_line:
    // スコア +1
    adrp x0, score@PAGE
    add x0, x0, score@PAGEOFF
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // 行0を全部0にする
    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF
    mov w4, #0
    mov w6, #0
clear_top:
    strb w6, [x0, w4, uxtw]
    add w4, w4, #1
    cmp w4, #10
    b.lt clear_top

    // 同じ行をもう一度チェック（連続消去対応）
    b check_line_loop

set_next:
    mov w22, #0
    mov w20, #4

    // ゲームオーバーチェック：新しいミノの出現位置にブロックがあるか
    // w21のミノ回転0の4マスをチェック
    mov w8, w21
    lsl w8, w8, #2
    lsl w8, w8, #4       // 回転0なのでw22=0, (w21*4+0)*16
    adrp x9, mino_data@PAGE
    add x9, x9, mino_data@PAGEOFF
    add x9, x9, w8, uxtw

    adrp x0, fixed_board@PAGE
    add x0, x0, fixed_board@PAGEOFF

    ldr w8, [x9, #0]
    add w8, w8, w20
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq game_over

    ldr w8, [x9, #4]
    add w8, w8, w20
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq game_over

    ldr w8, [x9, #8]
    add w8, w8, w20
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq game_over

    ldr w8, [x9, #12]
    add w8, w8, w20
    ldrb w6, [x0, w8, uxtw]
    cmp w6, #1
    b.eq game_over

    b game_loop

game_over:
    mov x0, #0
    mov x1, #0
    adrp x2, termios_orig@PAGE
    add x2, x2, termios_orig@PAGEOFF
    bl _tcsetattr

    // "GAME OVER\n"表示
    mov x0, #1
    adrp x1, msg_gameover@PAGE
    add x1, x1, msg_gameover@PAGEOFF
    mov x2, #10
    mov x16, #4
    svc #0x80

    // "Lines: "表示
    mov x0, #1
    adrp x1, msg_score@PAGE
    add x1, x1, msg_score@PAGEOFF
    mov x2, #7
    mov x16, #4
    svc #0x80

    // スコアを数字に変換して表示
    adrp x0, score@PAGE
    add x0, x0, score@PAGEOFF
    ldr w20, [x0]        // w20 = スコア

    // 数字を文字列に変換（最大3桁）
    sub sp, sp, #16
    mov w21, #0          // 桁数カウンタ

    // 0の場合
    cmp w20, #0
    b.ne convert_loop
    mov w1, #'0'
    strb w1, [sp]
    mov w21, #1
    b print_score

convert_loop:
    cmp w20, #0
    b.eq print_score_setup
    mov w3, #10
    udiv w2, w20, w3     // w2 = w20 / 10
    msub w1, w2, w3, w20 // w1 = w20 % 10
    add w1, w1, #'0'     // 数字→文字
    strb w1, [sp, w21, uxtw]
    add w21, w21, #1
    mov w20, w2
    b convert_loop

print_score_setup:
    // 逆順になっているので反転して表示
    sub w21, w21, #1     // 最後の桁のインデックス

print_score:
    cmp w21, #0
    b.lt print_newline
    ldrb w1, [sp, w21, uxtw]
    // 1文字表示
    strb w1, [sp, #8]
    mov x0, #1
    add x1, sp, #8
    mov x2, #1
    mov x16, #4
    svc #0x80
    sub w21, w21, #1
    b print_score

print_newline:
    mov x0, #1
    adrp x1, msg_newline@PAGE
    add x1, x1, msg_newline@PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    add sp, sp, #16
    ldp x29, x30, [sp], #16
    mov x0, #0
    mov x16, #1
    svc #0x80

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