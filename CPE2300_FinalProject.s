# Conway's Game of Life in Assembly
# by Will Bakey, Daiki Hew, and Logan Chook

.data
# -- VGA Display
.equ FB,      0x20000000
.equ PAL,     0x21000000
.equ PRESENT, 0x21001008
# -- Grid/Cell Info (16x12 cell grid)
.equ W,       192	# width of screen
.equ CELLW,   16	# width of each cell
.equ L,       144       # length of screen
.equ CELLL,   12        # length of each cell
.equ TOTALCELLS, 192    # Cell length x width
# 2 Separate Grids for Double Buffering
gridA: .space TOTALCELLS
gridB: .space TOTALCELLS
currentGrid: .word gridA  # pointer for gridA
nextGrid: .word gridB     # pointer for gridB

.text
.globl main
main:


    # Exit the program safely
    li   a7, 10                           # exit
    ecall
