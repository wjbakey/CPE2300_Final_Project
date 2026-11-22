# Conway's Game of Life in Assembly
# by Will Bakey, Daiki Hew, and Logan Chook

.data
#-- Input Handling
.equ KEYHIT_ADDR, 0x4000002C #Key buffer
# -- VGA Display
.equ FB,      0x20000000 #frame buffer
.equ PAL,     0x21000000 #palette
.equ PRESENT, 0x21001008 #present
.equ DEAD_COLOR, 1	#Dead palette index
.equ ALIVE_COLOR, 2	#Alive palette index
.equ LINE_COLOR, 3	#Grid line palette index
# -- Grid/Cell Info (16x12 cell grid)
.equ W,       192
.equ L,       144       # length of screen
.equ COLS,   16		# # of colums
.equ ROWS,   12        # # of rows
.equ CELL_SIZE, 12	# width of each cell in pixels
.equ TOTALCELLS, 192    # rows*cols
# 2 Separate Grids for Double Buffering
gridA: .space 192
gridB: .space 192
currentGrid: .word 0  # pointer for gridA
nextGrid: .word 0     # pointer for gridB

.text
.globl main
main:
#Initialize the grids
	la t0, gridA
	la t1, currentGrid
	sw t0, 0(t1)
	la t0, gridB
	la t1, nextGrid
	sw t0, 0(t1)

#Set up palette
	li   t0, PAL
	li   t1, 0x000000      # palette[1] = black
	sw   t1, 4(t0)
	li   t1, 0xFFDC00      # palette[2] = yellow
	sw   t1, 8(t0)
	li   t1, 0xAAAAAA      # palette[3] = gray
	sw   t1, 12(t0)

	# Load initial pattern
	call initialize_grid

	# Draw initial generation
	call draw_grid
	call present_frame

	# Calculate, swap, draw, and show one generation
	call step_and_draw
	call step_and_draw
    
	j exit

# Returns the current keypress in a0
read_key:
	li t0, KEYHIT_ADDR	#Loads the address of the key register
	lw a0 ,0(t0)		#Reads the value
	ret

# Sets up the grid to a predefined set of alive cells
initialize_grid:	# a0 = value to clear to, a1 = grid address, a2 = end of grid address
	addi sp, sp, -16
	sw ra, 0(sp)
# Clear both grids
	li a0, 0	# A zero to load into each cell
	la a1, currentGrid	# Pointer for gridA (used as loop index)
	lw a1, 0(a1)
	li t0, TOTALCELLS	# size of gridA
	add a2, a1, t0	# Pointer for end of gridA
	call clear_grid
	la a1, nextGrid	# Pointer for gridB (loop index)
	lw a1, 0(a1)
	add a2, a1, t0	# gridB space
	call clear_grid
# Restore the original buffer assignments
	
	j initialize_exit
# Loads the specified cell with either a 1 or 0
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
	lw ra, 0(sp)
	addi sp, sp, 16
	ret
# Counts Neighbors and returns # in a0 (Cells above, below, left, right, and diagonal)
# count_neighbors(a0 = row, a1 = col)
count_neighbors:
	li t0, 0 # count of neighbors
	
	# initial neighbor row
	li t1, -1 # row
	
	row_loop:
	li t2, 1 # upper row limit
	bgt t1, t2, count_neighbor_exit # if row > 1, exit loop
	
	# initial neighbor col
	li t2, -1 # col
	
	col_loop:
	li t3, 1 # upper col limit
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
	la t6, currentGrid
	lw t6, 0(t6)
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


# Calculates the next generation and stores it in nextGrid
update_generation:
	# Save return address before calling another function
	addi sp, sp, -16
	sw ra, 0(sp)
	sw s0, 4(sp)
	sw s1, 8(sp)
	li s0, 0 # Row

outer_loop:
	li t0, ROWS
	bge s0, t0, complete # If all rows are done, finish update

	li s1, 0 # Column

inner_loop:
	
	li t0, COLS
	bge s1, t0, outer_next # If row done, go to next row

	# Counting neighbors around current cell
	mv a0, s0
	mv a1, s1
	call count_neighbors

	# Calculating grid index: row * COLS + col
	li t0, COLS
	mul t1, s0, t0
	add t1, t1, s1

	# Get current cell state
	la t2, currentGrid
	lw t2, 0(t2)
	add t3, t2, t1
	lb t3, 0(t3)

	# Default next state is dead
	li t4, 0

	# Check if current cell is alive
	li t5, 1
	bne t3, t5, else

	# Alive cells survives with 2 or 3 neighbors
	li t5, 2
	beq a0, t5, alive

	li t5, 3 
	beq a0, t5, alive

else:
	# Dead cells can become alive with 3 neighbors
	li t5, 3
	bne a0, t5, next_state

alive:
	li t4, 1 # Set next state to alive

next_state:
	# Store next cell state into next grid
	la t5, nextGrid
	lw t5, 0(t5)
	add t6, t5, t1
	sb t4, 0(t6)

	addi s1, s1, 1 #Increase count for columns
	j inner_loop # Move to next column

outer_next:
	addi s0, s0, 1 # Increase row count
	j outer_loop # Move to next row

complete:
	# Restore the return address and return
	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	addi sp, sp, 16
	ret

# Swaps current grid with newly calculated grid
swap_buffers:
	la t0, currentGrid # Address of currentGrid
	lw t1, 0(t0)      #Address of gridA
	la t2, nextGrid #Address of nextGrid
	lw t3, 0(t2)    #Address of gridB

	sw t3, 0(t0) # New grid becomes current grid
	sw t1, 0(t2) # Old grid becomes new grid
	ret

# Updates the grid by one generation
step_generation:
	addi sp, sp, -4
	sw ra, 0(sp)

	call update_generation # Call the update generation function
	call swap_buffers # Call the swap buffers function

	lw ra, 0(sp)
	addi sp, sp, 4
	ret

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
	bge s2, s0, draw_cell_return #If pixel outside of cell, exit function
	li s3, 0 #current col
draw_cell_inner:
	mv t4, s1 #Temp drawing color
	bge s3, s0, draw_cell_indexing #If pixel outside of cell, next row
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
	
# draws the entire grid on the VGA
draw_grid:
	# stores saved registers/address
	addi sp, sp, -32
	sw ra, 0(sp) # return address
	sw s0, 4(sp) # number of rows
	sw s1, 8(sp) # number of cols
	sw s2, 12(sp) # row counter
	sw s3, 16(sp) # col counter
	sw s4, 20(sp) # index
	sw s5, 24(sp) # currentGrid
	
	li s0, ROWS # number of rows
	li s1, COLS # number of cols
	li s2, 0 # row counter
	
	draw_grid_row_loop:
	li s3, 0 # col counter
	bge s2, s0, draw_grid_exit # if row >= ROWS exit loop
	
	draw_grid_col_loop:
	bge s3, s1, draw_grid_row_exit # if col >= COLS exit loop
	
	# index = COLS * row + col
	mv s4, s1
	mul s4, s4, s2
	add s4, s4, s3
	
	# state = currentGrid[index]
	la s5, currentGrid
	lw s5, 0(s5)
	add s4, s4, s5 # address of cell
	lb s5, 0(s4) # cell state
	
	# draw_cell parameters
	mv a0, s3 # cell col
	mv a1, s2 # cell row
	mv a2, s5 # state
	
	call draw_cell
	
	draw_grid_col_exit: # + 1 col count --> loop
	addi s3, s3, 1
	j draw_grid_col_loop
	
	draw_grid_row_exit: # + 1 row count --> loop
	addi s2, s2, 1
	j draw_grid_row_loop
	
	draw_grid_exit:
	
	# restore saved registers/address
	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	lw s2, 12(sp)
	lw s3, 16(sp)
	lw s4, 20(sp)
	lw s5, 24(sp)
	addi sp, sp, 32
	
	ret

# presents the drawn grid for the frame on the VGA
present_frame:
	li t0, PRESENT # present address
	li t1, 1 # present flag
	sw t1, 0(t0)
	ret
	
# Calculates, swaps, draws, and displays one new generation
step_and_draw:

	addi sp, sp, -16
	sw ra, 0(sp)

	call update_generation # Calculate the next generation
	call swap_buffers # Make the new generation current
	call draw_grid # Draw the updated grid
	call present_frame # Display the updated frame buffer
	
	lw ra, 0(sp)
	addi sp, sp, 16
	ret

exit:
# Exit the program safely
	li   a7, 10                           # exit
	ecall
    
