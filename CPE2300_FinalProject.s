.data
# -- VGA Display
.equ FB,      0x20000000
.equ PAL,     0x21000000
.equ PRESENT, 0x21001008
# -- Grid/Cell Info (16x12 cell grid)
.equ W,       192	# width of screen
.equ CELLW,   16	# width of each cell

.text
.globl main
main:

    # Exit the program safely
    li   a7, 10                           # exit
    ecall
