// hello.s (Apple M5 / ARM64)
.global _main
.align 2

_main:
    // 1. 文字列を画面に出力 (writeシステムコール)
    mov     x0, #1              // ファイルディスクリプタ: 1 (stdout)
    adrp    x1, msg@PAGE        // 文字列のページアドレス
    add     x1, x1, msg@PAGEOFF // ページ内のオフセットを加算
    mov     x2, #13             // 文字列の長さ ("Hello, World\n")
    mov     x16, #4             // システムコール番号: 4 (write)
    svc     #0x80               // カーネルを呼び出して実行

    // 2. プログラムを正常終了 (exitシステムコール)
    mov     x0, #0              // 終了ステータス: 0
    mov     x16, #1             // システムコール番号: 1 (exit)
    svc     #0x80               // カーネルを呼び出して終了

.data
msg:
    .ascii "Hello, World\n"
