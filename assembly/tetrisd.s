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

.text
.global _main
.align 2

_main:

    //ループ準備
    mov w10, #0 //カウンター　(i = 0)


    adrp x0, board@PAGE //大まかな場所
    add x0, x0, board@PAGEOFF //正確なアドレス(オフセットの取得)
    //add 答えを入れる場所, 足したい数1, 足したい数2

    //mac M5は4096バイト以下の計算しかできへんから,@pageoffで制限する必要あり

    //x => 64 bit, w => 32 bit
    mov w1, #4 // x = 4
    mov w2, #0 // y = 0
    mov w3, #10 // width = 10

    //madd => 結果, かけた数1, かけた数2, 足したい数
    //結果 = (かけた数1 × かけた数2) + 足したい数
    madd w4, w2, w3, w1 // offset = y * width + x

    mov w5, #1
    //str 保存 b 1バイトだけ w5の値をx0からx4目のアドレスに保存
    strb w5, [x0, x4]


    ldrb w6, [x0, x4] //保存した値を読み込む
    cmp w6, #1 //読み込んだ値が1かどうか比較
    b.ne skip_print //もし違うならスキンプリントというラベルまでjump


    //--画面表示処理--
    mov x0, #1 //書き込む先は1番(画面)
    adrp x1, msg_block@PAGE //表示したい文字の場所
    add x1, x1, msg_block@PAGEOFF
    mov x2, #1 //一文字だけ出す
    mov x16, #4 //writeという命令
    svc #0x80

skip_print:
    mov x0, #0
    mov x16, #1 
    svc #0x80