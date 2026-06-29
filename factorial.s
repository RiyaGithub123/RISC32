# factorial.s
# Computes 5! = 120 and stores/loads it in data memory at address 15

li x2, 1        # product = 1
li x1, 5        # counter = 5

loop:
mul x2, x2, x1  # product = product * counter
addi x1, x1, -1 # counter = counter - 1
bnez x1, loop   # if counter != 0, repeat

# Store result to memory at address 15
sw x2, 15(x0)

# Load result from memory to x4 to verify
lw x4, 15(x0)

halt            # Stop simulation
