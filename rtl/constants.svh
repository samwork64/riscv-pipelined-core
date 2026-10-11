`ifndef CONSTANTS
`define CONSTANTS
// Files
// `define INSTRUCTIONS_MEM    "instruction_memory.mem"
`define INSTRUCTIONS_MEM    "csr_test.mem"
// Parameters
`define INSTRUCTION_MEMORY_SIZE     32
`define REGISTER_FILE_SIZE          16
`define DATA_MEMORY_SIZE            64
`define REGISTER_SIZE               32
//Instruction Types
`define R_TYPE_INST         7'b0110011 // Register Instruction -> R-Type
`define I_TYPE_INST         7'b0010011 // Immediate Instruction -> I-Type
`define I_L_TYPE_INST       7'b0000011 // Load Instruction -> I-Type
`define I_JALR_TYPE_INST    7'b1100111 // Jump and Link Register Instruction -> I-Type
`define S_TYPE_INST         7'b0100011 // Store Instruction -> S-Type
`define B_TYPE_INST         7'b1100011 // Branch Instruction -> B-Type
`define U_LUI_TYPE_INST     7'b0110111 // Load Upper Immediate Instruction -> U-Type
`define U_AUIPC_TYPE_INST   7'b0010111 // Add Upper Immediate to Program Counter Instruction -> U-Type
`define J_TYPE_INST         7'b1101111 // Jump Instruction -> J-Type
`define CSR_INST            7'b1110011  //CSR Instructions -> CSR
//ALU Operators
`define ADD     0       // Addition
`define SUB     1       // Subtraction
`define SLL     2       // Shift Left Logical
`define SLT     3       // Set Less Than
`define SLTU    4       // Set Less Than Unsigned
`define XOR     5       // XOR Operation
`define SRL     6       // Shift Right Logical
`define SRA     7       // Shift Right Arithmetic
`define OR      8       // OR Operation
`define AND     9       // AND Operation
`define PASS_A  10      // Pass inA to output
`define PASS_B  11      // Pass inB to output
`define JALR    12
//LOAD Operations
`define LOAD_BYTE              0
`define LOAD_HALF              1
`define LOAD_WORD              2
`define LOAD_BYTE_UNSIGNED     3
`define LOAD_HALF_UNSIGNED     4  
`define LOAD_X                 3'bxxx   
//STORE Operations
`define STORE_BYTE             0
`define STORE_HALF             1
`define STORE_WORD             2
`define STORE_X                2'bxx 
//Branch Type
`define BRANCH_EQUAL                    0
`define BRANCH_NOT_EQUAL                1
`define BRANCH_LESS_THAN                2
`define BRANCH_GREATER_EQUAL            3
`define BRANCH_LESS_THAN_UNSIGNED       4
`define BRANCH_GREATER_EQUAL_UNSIGNED   5
`define BRANCH_UNCONDITIONAL            6
`define BRANCH_NONE                     7
//Decision
`define YES 1
`define NO  0
//NOP Instruction
`define NOP_INST 32'h00000013
//CSR
//Registers
`define MSTATUS 12'h300
`define MIE     12'h304
`define MTVEC   12'h305
`define MEPC    12'h341
`define MCAUSE  12'h342
`define MIP     12'h344
//Instructions
`define CSRRW   3'b001
//RET func7
`define MRET    7'b0011000
`define SRET    7'b0001000
`define MNRET    7'b0111000
//MCAUSE Interrupts Exception code
`define SUPERVISOR_SOFTWARE_INTERRPUT   1
`define MACHINE_SOFTWARE_INTERRPUT      3
`define SUPERVISOR_TIMER_INTERRPUT      5
`define MACHINE_TIMER_INTERRPUT         7
// `define SUPERVISOR_TIMER_INTERRPUT      9
// Define a flexible Doesn't Matter macro
`define DOES_NOT_MATTER(size) {size{1'bx}}

`endif


