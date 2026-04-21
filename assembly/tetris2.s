.data
.align 4 //メモリを4バイト境界に揃える

//<フィールド作成>
//0: 空白 1: ブロック 2: 壁
board:
    .zero 200 //10*20のフィールドを0でうめる


//今操作しているミノの位置
current_x:
    .word 4 //横位置 (初期は中央)

current_y:
    .word 0 //縦位置 (初期は一番上)

current_type:
    .word 0 //ミノの種類 (0-6)

msg_block:
    .ascii "X"

msg_dot:
    .ascii "."

msg_newline:
    .ascii "\n"

clear_screen:
    .ascii "\033[H\033[J" // カーソルを左上に戻して画面を消去するやつ

sleep_time:
    .word 500000 // 0.5秒 (500,000μs)

.text
.global _main
.align 2

_main:
    //一旦ブロック設置
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    mov w1, #1
    strb w1, [x0, #4] //board[4]にブロック設置

    //ループ準備
    mov w10, #0 // i = 0

game_loop:
    //画面をクリア
    mov x0, #1
    adrp x1, clear_screen@PAGE
    add x1, x1, clear_screen@PAGEOFF
    mov x2, #7 //文字の長さ
    mov x16, #4
    svc #0x80 //実行


    //boardへの書き込み
    mov w10, #0
    mov w11, #10
draw_loop:
    //メモリから値を読み出す
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    ldrb w6, [x0, x10] //番目のマスを読み込む

    //1 = "X", 0 = "."
    cmp w6, #1
    b.eq print_x // 1ならprint_xへ

print_dot:
    adrp x1, msg_dot@PAGE //"."の場所
    add x1, x1, msg_dot@PAGEOFF
    b do_print

print_x:
    adrp x1, msg_block@PAGE //"X"　の場所
    add x1, x1, msg_block@PAGEOFF

do_print:
    mov x0, #1 //書き込む先
    mov x2, #1 //一文字
    mov x16, #4 //write命令形
    svc #0x80 //実行

    //改行判定の追加
    sub w11, w11, #1 // -1
    cmp w11, #0
    b.ne next_step // 0じゃなかったら次のマスへ

    //改行(\n)を表示
    mov x0, #1
    adrp x1, msg_newline@PAGE
    add x1, x1, msg_newline@PAGEOFF
    mov x2, #1
    mov x16, #4
    svc #0x80

    mov w11, #10 //10にリセット

next_step:     
    add w10, w10, #1 //i ++
    cmp w10, #200 //200と比較
    b.lt draw_loop //less than 200 ならdraw_loopへ


    b game_loop





    //終了
    mov x0, #0
    mov x16, #1
    svc #0x80