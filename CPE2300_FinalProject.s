# Conway's Game of Life in Assembly
# by Will Bakey, Daiki Hew, and Logan Chook

.data
# -- VGA Display
.equ FB,      0x20000000
.equ PAL,     0x21000000
.equ PRESENT, 0x21001008
# -- Grid/Cell Info (16x12 cell grid)
.equ W,       192	# width of screen
.equ L,       144       # length of screen
.equ COLS,   16		# # of colums
.equ ROWS,   12        # # of rows
.equ TOTALCELLS, 192    # rows*cols

# 2 Separate Grids for Double Buffering
gridA: .space TOTALCELLS
gridB: .space TOTALCELLS
currentGrid: .word gridA  # pointer for gridA
nextGrid: .word gridB     # pointer for gridB

.text
.globl main
main:

# Sets up the grid to a predefined set of alive cells
initialize_grid:	# a0 = value to clear to, a1 = grid address, a2 = end of grid address
# Clear both grids
	li a0, 0	# A zero to load into each cell
	lw a1, currentGrid	# Pointer for gridA (used as loop index)
	li t0, TOTALCELLS	# size of gridA
	add a2, a1, t0	# Pointer for end of gridA
	call clear_grid
	lw a1, nextGrid	# Pointer for gridB (loop index)
	add a2, a1, t0	# gridB space
	call clear_grid
	lw a0, currentGrid	# Pointer for current grid
	li a1, 4		# Target column
	li a2, 5		# Target row
	li a3, 1		# Load cell with 1 (alive)
	call load_cell
	lw a0, currentGrid	# Pointer for current grid
	li a2, 6		# Target row
	call load_cell
	lw a0, currentGrid	# Pointer for current grid
	li a2, 7		# Target row
	call load_cell
	j initialize_exit
# Set up initial cells
load_cell:	# a0 = grid pointer, a1 = column, a2 = row, a3 = value (1 or 0)
	li t0, COLS
	mul t1, a2, t0
	add t1, t1, a1
	add a0, t1, a0
	sb a3, 0(a0)
	ret
# Clears the whole grid to 0's ("Dead" cells)
clear_grid:
	bge a1, a2, clear_grid_return
	sb a0, 0(a1)	# Clear the cell to 0
	addi a1, a1, 1	# Next cell
	j clear_grid
clear_grid_return:
	ret
initialize_exit:

exit:
    # Exit the program safely
    li   a7, 10                           # exit
    ecall
