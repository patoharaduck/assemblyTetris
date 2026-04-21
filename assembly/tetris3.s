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

.align 8
termios_orig:
    .zero 72 //元の設定を保存する場所

termios_new:
    .zero 72 //改造をの設定を置く場所

input_buf:
    .byte 0 //読み込んだキーを入れる場所



.text
.global _main
.align 2

_main:
    stp x29, x30, [sp, #-16]! // 現在地を保存
    //x29 と x30 の中身を、スタック（sp）というメモリ領域にまとめて放り込む

    // terminalのENTERを不要にする
    mov x0, #0 //保存領域を指定
    adrp x1, termios_orig@PAGE //住所
    add x1, x1, termios_orig@PAGEOFF
    bl _tcgetattr //現在の設定を取得　命令みたいなもん
    //bl 関数を呼び出す命令(bと違って元に戻ってくる)
    //_tcgetattr 現在のターミナル（キーボードや画面）の設定を、メモリに読み出す

    //設定をコピーして改造
    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    adrp x1, termios_orig@PAGE
    add x1, x1, termios_orig@PAGEOFF
    mov x2, #72
    bl _memcpy //設定をコピー

    //非カノニカルモード（Enter不要）とエコーオフを設定
    //非カノニカルモード => Enter入らずに入力できる
    //エコーオフ => 文字を打ってもターミナルに表示されない
    adrp x0, termios_new@PAGE
    add x0, x0, termios_new@PAGEOFF
    ldr x1, [x0, #12] //c_lflag取得

    // (ldr x1, [x0, #12] の後)
    // 1. ECHO(0x8) と ICANON(0x100) を狙い撃ちで消す
    mov     x2, #0x108          // 消したいビットの塊
    bic     x1, x1, x2          // bic命令は指定ビットを確実に0にする
    str     x1, [x0, #12]

    // 2. VMIN=0, VTIME=0 の設定 (Macの正しい位置は 16, 17バイト目)
    // x0 は termios_new の先頭を指しているはず
    add     x2, x0, #16         // c_cc配列の開始位置
    mov     w3, #0
    strb    w3, [x2, #16]       // VMIN = 0
    strb    w3, [x2, #17]       // VTIME = 0

    mov x0, #0
    mov x1, #0
    adrp x2, termios_new@PAGE //キーボードに対して
    add x2, x2, termios_new@PAGEOFF //いますぐ
    bl _tcsetattr //新しい設定を反映


    //最初のブロックの位置
    mov w20, #4

game_loop:
    // 1. 画面クリア
    mov x0, #1
    adrp x1, clear_screen@PAGE
    add x1, x1, clear_screen@PAGEOFF
    mov x2, #7
    mov x16, #4
    svc #0x80

    // 2. ボードを全部0にリセット
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

    // 5. 待機
    mov x0, #500000
    bl _usleep

    //キー入力の読み込み
    mov x0, #0 //標準入力
    adrp x1, input_buf@PAGE
    add x1, x1, input_buf@PAGEOFF
    mov x2, #1 //一文字だけ
    mov x16, #3 //read命令 => キーボードやファイルからデータを受け取る

    // 読み込む前にリセット
    adrp x1, input_buf@PAGE
    add x1, x1, input_buf@PAGEOFF
    mov w8, #0
    strb w8, [x1]

    svc #0x80

    //ゲームの終了
    ldrb w7, [x1]
    cmp w7, #'q' 
    b.eq quit_game


    //左右に動かす
    ldrb w7, [x1] //入力された文字をw7に入れる
    cmp w7, #'a'
    b.eq move_left
    cmp w7, #'d'
    b.eq move_right

    b after_input

move_left:
    sub w20, w20, #1
    b after_input

move_right:
    add w20, w20, #1


after_input:
    //今のブロックを消す
    adrp x0, board@PAGE
    add x0, x0, board@PAGEOFF
    mov w1, #0
    strb w1, [x0, x20] //w20の位置を0に戻す

    //一行下げる
    add w20, w20, #10

    //そこについたら上に戻す
    cmp w20, #200
    b.lt game_loop

    mov w20, #4
    b game_loop

quit_game:
    mov x0, #0
    mov x1, #0
    adrp x2, termios_orig@PAGE
    add x2, x2, termios_orig@PAGEOFF
    bl _tcsetattr //元の設定に戻す


    //終了
    ldp x29, x30, [sp], #16 //保存した場所を戻す
    mov x0, #0
    mov x16, #1
    svc #0x80