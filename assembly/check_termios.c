#include <stdio.h>
#include <termios.h>
#include <stddef.h>

int main() {
    struct termios t;
    printf("sizeof termios: %zu\n", sizeof(t));
    printf("offsetof c_iflag: %zu\n", offsetof(struct termios, c_iflag));
    printf("offsetof c_oflag: %zu\n", offsetof(struct termios, c_oflag));
    printf("offsetof c_cflag: %zu\n", offsetof(struct termios, c_cflag));
    printf("offsetof c_lflag: %zu\n", offsetof(struct termios, c_lflag));
    printf("offsetof c_cc:    %zu\n", offsetof(struct termios, c_cc));
    printf("VMIN index: %d\n", VMIN);
    printf("VTIME index: %d\n", VTIME);
    printf("VMIN offset: %zu\n", offsetof(struct termios, c_cc) + VMIN);
    printf("VTIME offset: %zu\n", offsetof(struct termios, c_cc) + VTIME);
    return 0;
}
