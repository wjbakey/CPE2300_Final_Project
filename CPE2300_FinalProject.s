# Conway's Game of Life in Assembly
# by Will Bakey, Daiki Hew, and Logan Chook

.data
# -- VGA Display
.equ FB,      0x20000000 #frame buffer
.equ PAL,     0x21000000 #palette
.equ PRESENT, 0x21001008 #present
.equ DEAD_COLOR, 1	#Dead palette index
.equ ALIVE_COLOR, 2	#Alive palette index
.equ LINE_COLOR, 3	#Grid line palette index
# -- Grid/Cell Info (16x12 cell grid)
.equ W,       192	# width of screen
.equ L,       144       # length of screen
.equ COLS,   16		# # of colums
.equ ROWS,   12        # # of rows
.equ CELL_SIZE 12	# width of each cell in pixels
.equ TOTALCELLS, 192    # rows*cols
# 2 Separate Grids for Double Buffering
gridA: .space TOTALCELLS
gridB: .space TOTALCELLS
currentGrid: .word gridA  # pointer for gridA
nextGrid: .word gridB     # pointer for gridB

.text
.globl main
main:
#Set up palette
	li   t0, PAL
	li   t1, 0x000000      # palette[1] = black
	sw   t1, 4(t0)
	li   t1, 0xFFDC00      # palette[2] = yellow
	sw   t1, 8(t0)
	li   t1, 0xAAAAAA      # palette[3] = gray
	sw   t1, 12(t0)
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

# Colors an individual pixel on the VGA
draw_pixel:	#a0=x(COL), a1=y(ROW), a2=palette_index
	# Calculate the pixel index (i = y*W+x)
	li t0, W # Screen width
	mul t1, a1, t0	# y*W
	add t1, t1, a0	# +x
	# Load color to framebuffer
	li t2, FB	#framebuffer
	add t2, t2, t1	#add index to framebuffer
	sb a2, 0(t2)	#store palette index at cell index
	ret

# Colors an entire cell on the VGA
draw_cell: #a0=cell col, a1=cell row, a2=state (dead/alive)
	#Store saved registers/return address
	addi sp, sp, -32
	sw ra, 0(sp) #return address
	sw s0, 4(sp) #cell size
	sw s1, 8(sp) #cell color
	sw s2, 12(sp)#row counter
	sw s3, 16(sp)#col counter
	sw s4, 20(sp)#starting col coord
	sw s5, 24(sp)#starting row coord

	# Convert grid coords to pixel coords
	li s0, CELL_SIZE
	mul s4, a0, s0	#starting col (pixel coords)
	mul s5, a1, s0	#starting row (pixel coords)
	# Choose color based on state
	li s1, DEAD_COLOR
	li t0, 1
	bne a2, t0, alive_color_skip #If cell is alive, change to alive color
	li s1, ALIVE_COLOR
	alive_color_skip:
	# Drawing cell (nested for loop)
	li s2, 0 #current row
draw_cell_outer:
	bge s2, s0, draw_cell_return #If pixel outside of cell, next row
	li s3, 0 #current col
draw_cell_inner:
	mv t4, s1 #Temp drawing color
	bge s3, s0, draw_cell_indexing #If pixel outside of cell, next col
	beqz s2, color_grid_line # if pixel is row 0, gridline
	beqz s3, color_grid_line # if pixel is col 0, gridline
	j grid_line_skip
	color_grid_line:
	li t4, LINE_COLOR
	grid_line_skip:
	#Prepare arguments
	add a0, s3, s4 #COL
	add a1, s5, s2 #ROW
	mv a2, t4 #PALETTE
	# Draw the pixel
	call draw_pixel
	#Index the column
	addi s3, s3, 1 #next col
	j draw_cell_inner
draw_cell_indexing:
	addi s2, s2, 1 #next row
	j draw_cell_outer
draw_cell_return:
	#Restore saved registers/ra
	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	lw s2, 12(sp)
	lw s3, 16(sp)
	lw s4, 20(sp)
	lw s5, 24(sp)
	addi sp, sp, 32
	ret
	
exit:
    # Exit the program safely
    li   a7, 10                           # exit
    ecall
    