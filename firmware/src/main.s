.global csr

csr:
    li x11, 0x00000880          # Set x11 to 32-bit hex 0x880
    li x12, 0x00000008          # Set x12 to 32-bit hex 0x8
    la x13, interrupt_handler   # Load the address of interrupt_handler into x13
    
    #ori x13, x13, 1             # Set mtvec[0] to 1 to enable Vector Mode
    csrrw x0, mie, x11          # Write x11 value to mie register
    csrrw x0, mstatus, x12      # Write x12 value to mstatus register
    csrrw x0, mtvec, x13        # Write x13 value (interrupt_handler address) to mtvec register

loop:
    addi x14, x14, 1         # Increment x14 by 1
    j loop                   # Jump back to loop

interrupt_handler:
    csrrw x0, mie, x0        # Restore mie register
    li x2, 0xFFFFFFFF        # Load x2 with 0xFFFFFFFF
    xor x3, x3, x2           # XOR x3 with x2 (x3 = 0)
    csrrw x0, mie, x11       # Restore mie register again
    csrrw x15, mip, x0       # Store mip register value in x15
    mret                     # Return from interrupt
