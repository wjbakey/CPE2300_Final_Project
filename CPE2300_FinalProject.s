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

# Counts Neighbors and returns # in a0 (Cells above, below, left, right, and diagonal)
# count_neighbors(a0 = row, a1 = col)
count_neighbors:
	li t0, 0 # count of neighbors
	
	# initial neighbor row
	li t1, -1 # row
	
	row_loop:
	li t2, 1
	bgt t1, t2, count_neighbor_exit # if row <= 1, enter loop
	
	# initial neighbor col
	li t2, -1 # col
	
	col_loop:
	li t3, 1
	bgt t2, t3, row_loop_end # if col > 1, skip
	
	# (row == 0 && col == 0)
	# skip this loop iteration if we are looking at the center cell
	# (It shouldn't count itself as a neighbor) 
	bnez t1, col_loop_skip
	beqz t2, col_loop_end
	
	col_loop_skip:
	mv t3, a0 # grabs cell row
	add t3, t3, t1 # neighbor cell row
	mv t4, a1 # grabs cell col
	add t4, t4, t2 # neighbor cell col
	
	# continues loop if outside row domain (edge case)
	li t5, ROWS
	bltz t3, row_loop_end # row < 0 (negative), then skip
	bge t3, t5, row_loop_end # row >= total rows, then skip
	
	# continues loop if outside col range (edge case)
	li t5, COLS
	bltz t4, col_loop_end # col < 0 (negative), then skip
	bge t4, t5, col_loop_end # col >= total cols, then skip
	
	# index = neighbor row * COLS + neighbor col
	li t6, COLS
	mv t5, t3 # index = neighbor row
	mul t5, t5, t6 # index * COLS
	add t5, t5, t4 # index + neighbor col
	
	# count += currentGrid[index]
	lw t6, currentGrid
	add t5, t5, t6 # address of cell
	lb t6, 0(t5) # state of currentCell
	add t0, t0, t6 # add to count
	
	col_loop_end:
	addi t2, t2, 1 # neighbor col + 1
	j col_loop
	
	row_loop_end:
	addi t1, t1, 1 # neighor row + 1
	j row_loop
	
	count_neighbor_exit:
	mv a0, t0
	ret

update_generation:
	li s0, 0 # Rows

outer_loop:
	li t0, ROWS
	bge s0, t0, complete

	li s1, 0 # Columns

inner_loop:
	
	li t0, COLS
	bge s1, t0, outer_next

	# Counting neighbors 
	mv a0, s0
	mv a1, s1
	call count_neighbors

	# Calculating the index (t1)
	li t0, COLS
	mul t1, s0, t0
	add t1, t1, s1

	# Determining the cell state
	lw t2, currentGrid
	add t3, t2, t1
	lb t3, 0(t3)
	li t4, 0

	# If / Else statements depedent on cell state
	li t5, 1
	bne t3, t5, else

	li t5, 2
	beq a0, t5, alive

	li t5, 3 
	beq a0, t5, alive

else:
	li t5, 3
	bne a0, t5, next_state

alive:
	li t4, 1

next_state:
	lw t5, nextGrid
	add t6, t5, t1
	sb t4, 0(t6)

	addi s1, s1, 1 #Increase count for columns
	j inner_loop # Move back to inner loop

outer_next:
	addi s0, s0, 1
	j outer_loop # Move back to outer loop

complete:
	ret

swap_buffers:
	lw t0, currentGrid # temp -> current Grid
	lw t1, nextGrid 

	sw t1, currentGrid # current Grid -> nextGrid
	sw t0, nextGrid # next Grid -> temp

exit:
    # Exit the program safely
    li   a7, 10                           # exit
    ecall
