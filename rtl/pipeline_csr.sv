`include "constants.svh"

module program_counter (
    input logic 
        clk, reset, br_taken, epc_taken,
        [31:0]jump_address, epc_evec,
    output logic 
        [31:0]pc
    );
    always @(posedge clk or posedge reset) begin
        if (reset) 
            pc <= 0;
        else
            pc <= epc_taken ? epc_evec : (br_taken ? jump_address : pc + 4);
    end
endmodule

module instruction_memory (input logic [31:0]address, output logic [31:0]inst_machine_code);
    logic [31:0]inst_memory[`INSTRUCTION_MEMORY_SIZE-1:0];
    //read instruction memory
    initial begin
        $readmemh (`INSTRUCTIONS_MEM, inst_memory); 
    end 
    //read current instruction
    always_comb inst_machine_code <= inst_memory[address>>2];
endmodule

module immediate_generator (
    input logic [31:0] inst_machine_code,
    output logic [31:0] immediate_value
    );
    logic [6:0] opcode;
    assign opcode = inst_machine_code[6:0];

    always_comb begin
        case (opcode)
            `I_TYPE_INST, `I_L_TYPE_INST, `I_JALR_TYPE_INST, `CSR_INST:
                immediate_value = {{20{inst_machine_code[31]}}, inst_machine_code[31:20]};

            `S_TYPE_INST:
                immediate_value = {{20{inst_machine_code[31]}}, inst_machine_code[31:25], inst_machine_code[11:7]};

            `B_TYPE_INST:
                immediate_value = {{19{inst_machine_code[31]}}, inst_machine_code[31], inst_machine_code[7], inst_machine_code[30:25], inst_machine_code[11:8], 1'b0};

            `U_LUI_TYPE_INST, `U_AUIPC_TYPE_INST:
                immediate_value = {inst_machine_code[31:12], 12'b0};

            `J_TYPE_INST:
                immediate_value = {{11{inst_machine_code[31]}}, inst_machine_code[31], inst_machine_code[19:12], inst_machine_code[20], inst_machine_code[30:21], 1'b0};

            default:
                immediate_value = 0;
        endcase
    end
endmodule

module control_signals (
    input logic 
        [31:0]inst_machine_code, 
    output logic 
        reg_wr, 
        sel_A,
        sel_B, 
        rd_en, 
        wr_en, 
        csr_reg_rd,
        csr_reg_wr,
        is_mret,
        [1:0]wb_sel, wr_op, 
        [2:0]rd_op, br_type,
        [3:0]alu_op
    );

    logic [6:0]opcode, func7;
    logic [2:0]func3;

    assign opcode = inst_machine_code[6:0];
    assign func7 = inst_machine_code[31:25];
    assign func3 = inst_machine_code[14:12];
    
    always_comb begin
        // Single Cycle Registers
        reg_wr      = `NO;
        rd_en       = `NO;
        wr_en       = `NO;
        sel_A       = 0;
        sel_B       = 0; 
        wb_sel      = 0;
        alu_op      = `ADD;
        rd_op       = 0;
        wr_op       = 0;
        csr_reg_wr  = `NO;
        csr_reg_rd  = `NO;
        is_mret     = `NO;
        br_type     = `BRANCH_NONE;
        
        case(opcode)
            `R_TYPE_INST : begin
	            reg_wr <= `YES;
                case (func7)
                    7'b0000000 : begin
                        case (func3)
                            3'b000 : alu_op <= `ADD;
                            3'b001 : alu_op <= `SLL;
                            3'b010 : alu_op <= `SLT;
                            3'b011 : alu_op <= `SLTU;
                            3'b100 : alu_op <= `XOR;
                            3'b101 : alu_op <= `SRL;
                            3'b110 : alu_op <= `OR;
                            3'b111 : alu_op <= `AND;
                        endcase end
                    7'b0100000 : begin
                        case (func3)
                            3'b000 : alu_op <= `SUB;
                            3'b101 : alu_op <= `SRA;
                        endcase end
                    default : alu_op <= `ADD;
                endcase 
            end

            `I_TYPE_INST : begin
                reg_wr <= `YES;
                sel_B  <= 1;
                case (func3)
                    3'b000 : alu_op <= `ADD;
                    3'b001 : if (func7 == 7'b0000000) alu_op <= `SLL;
                    3'b010 : alu_op <= `SLT;
                    3'b011 : alu_op <= `SLTU;
                    3'b100 : alu_op <= `XOR;
                    3'b101 : if (func7[6] == 0 && func7[4:0] == 0) alu_op <= func7[5] ? `SRA : `SRL;
                    3'b110 : alu_op <= `OR;
                    3'b111 : alu_op <= `AND;
                endcase
            end

            `I_L_TYPE_INST : begin 
                reg_wr <= `YES;
                sel_B  <= 1;
                rd_en  <= `YES;
                wb_sel <= 1;
                alu_op <= `ADD;
                case(func3)
                    3'b000 : rd_op <= `LOAD_BYTE;   
                    3'b001 : rd_op <= `LOAD_HALF;
                    3'b010 : rd_op <= `LOAD_WORD;
                    3'b100 : rd_op <= `LOAD_BYTE_UNSIGNED;
                    3'b101 : rd_op <= `LOAD_HALF_UNSIGNED;
                endcase 
            end

            `I_JALR_TYPE_INST : begin
                sel_B  <= 1;
                alu_op <= `ADD; 
                reg_wr <= `YES; 
                wb_sel <= 2;
                reg_wr <= `YES;
                br_type <= `BRANCH_UNCONDITIONAL; 
            end

            `S_TYPE_INST : begin
                wr_en  <= `YES;
                alu_op <= `ADD; 
                sel_B  <= 1;
                case(func3)
                    2'b00 : wr_op <= `STORE_BYTE;
                    2'b01 : wr_op <= `STORE_HALF;
                    2'b10 : wr_op <= `STORE_WORD;
                endcase 
            end

            `B_TYPE_INST : begin
                sel_A  <= 1;
                sel_B  <= 1;
                alu_op <= `ADD;
                case (func3)
                    3'b000 : br_type <= `BRANCH_EQUAL;
                    3'b001 : br_type <= `BRANCH_NOT_EQUAL;
                    3'b100 : br_type <= `BRANCH_LESS_THAN;
                    3'b101 : br_type <= `BRANCH_GREATER_EQUAL;
                    3'b110 : br_type <= `BRANCH_LESS_THAN_UNSIGNED;
                    3'b111 : br_type <= `BRANCH_GREATER_EQUAL_UNSIGNED;
                    default: br_type <= `BRANCH_NONE;
                endcase
            end
            
            `U_LUI_TYPE_INST :  begin
                sel_B  <= 1;
                alu_op <= `PASS_B;
                wb_sel <= 1; 
                reg_wr <= `YES; 
            end

            `U_AUIPC_TYPE_INST : begin
                sel_A  <= 1;
                sel_B  <= 1;
                alu_op <= `ADD; 
                reg_wr <= `YES; 
            end

            `J_TYPE_INST :  begin
                sel_A  <= 1;
                sel_B  <= 1;
                alu_op <= `ADD;
                wb_sel <= 2;
                reg_wr <= `YES;
                br_type <= `BRANCH_UNCONDITIONAL; 
            end

            `CSR_INST : begin
                if (inst_machine_code[24:20] == 5'b00010 && inst_machine_code[19:7] == '0) 
                    case(func7)
                        `MRET   :   is_mret <= `YES;
                        `SRET   :   is_mret <= `NO;
                        `MNRET  :   is_mret <= `NO;
                    endcase
                else
                    case(func3)
                        `CSRRW  : begin
                            reg_wr      <= `YES;
                            wb_sel      <= 3;
                            csr_reg_rd  <= `YES;
                            csr_reg_wr  <= `YES; 
                        end
                    endcase
                end

            endcase
        end
endmodule

module pipeline_dynamic_registers #(parameter WIDTH = 32)  // Default width, but can be overridden when instantiated
    (
    input logic clk, reset, stall, flush,
    input logic [WIDTH-1:0] in_data,
    output logic [WIDTH-1:0] out_data
    );
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            out_data <= 0;  // Reset output to zero for the given WIDTH
        else if (flush)
            out_data <= `NOP_INST;   //nop instruction
        else if (!stall)
            out_data <= in_data;
    end
endmodule

module forwarding_stall_flush_unit (
    input logic [31:0] inst_stg2, inst_stg3,
    input logic reg_wr_stg3, br_taken, clk, reset,
    output logic for_A, for_B, stall_stg2, stall_stg3, flush
    );

    logic [31:0] stall_active;

    // Forwarding logic for operand A
    assign for_A =  (inst_stg3[6:0] != `I_L_TYPE_INST) &&
                    (inst_stg3[11:7] != 0) &&  // Ensure rd is not zero
                    (inst_stg3[11:7] == inst_stg2[19:15]) &&  // Check if rd matches rs1
                    reg_wr_stg3;  // Check if stage 3 is writing to a register
    // Forwarding logic for operand B
    assign for_B = (inst_stg3[6:0] != `I_L_TYPE_INST) &&
                    (inst_stg3[11:7] != 0) &&  // Ensure rd is not zero
                    (inst_stg3[11:7] == inst_stg2[24:20]) &&  // Check if rd matches rs2
                    reg_wr_stg3;  // Check if stage 3 is writing to a register
    // Flush signal based on branch taken condition
    assign flush = br_taken;

    // Sequential logic for stall control
    always_ff @(negedge clk or posedge reset) begin
        if ((!reset) && (inst_stg3[6:0] == `I_L_TYPE_INST) && ((inst_stg3[11:7] == inst_stg2[19:15]) || (inst_stg3[11:7] == inst_stg2[24:20])) && (!stall_active)) begin
            stall_stg2   <= 1;
            stall_stg3   <= 1;
            stall_active <= 1;
        end
        else begin
            stall_stg2   <= 0;
            stall_stg3   <= 0;
            stall_active <= 0;
        end
    end
endmodule

module register_file (
    input logic 
        clk, reset, reg_wr, 
        [4:0] ra1, ra2, wa,
        [31:0] wdata_reg, 
    output logic 
        [31:0] rd1, rd2
    );
    logic [31:0] registers[`REGISTER_FILE_SIZE-1:0];  // Register file with 16 registers
    // Reset and Write operations on the positive edge of the clock
    always @(negedge clk or posedge reset) begin 
        if (reset) begin
            // Initialize all registers to zero
            for (int i = 0; i < `REGISTER_FILE_SIZE; i++) begin
                registers[i] <= 32'b0;
            end
        end 
        else if (reg_wr && (wa > 0) && (wa < 16)) begin  // Ensure we do not write to x0
            $display("wa: %d, reg_wr: %b, wdata: %d", wa, reg_wr, wdata_reg);
            registers[wa] <= wdata_reg;  // Write data to register if wa is not x0
        end
    end 
    // Read operations
    assign rd1 = (ra1<16) ? registers[ra1] : 0;
    assign rd2 = (ra2<16) ? registers[ra2] : 0;
    // initial //begin 
    // registers = '{default: '0};
    // registers[1] <= 25;
    // registers[2] <= 9; end
endmodule

module branch_condition(
    input logic 
        [31:0]in1, in2,
        [2:0]br_type,
    output logic
        br_taken
    );
    always_comb
        case (br_type)
            `BRANCH_EQUAL                   : br_taken <= (in1 == in2) ? `YES : `NO;
            `BRANCH_NOT_EQUAL               : br_taken <= (in1 != in2) ? `YES : `NO;
            `BRANCH_LESS_THAN               : br_taken <= ($signed(in1) <  $signed(in2)) ? `YES : `NO;
            `BRANCH_GREATER_EQUAL           : br_taken <= ($signed(in1) >= $signed(in2)) ? `YES : `NO;
            `BRANCH_LESS_THAN_UNSIGNED      : br_taken <= (in1 <  in2) ? `YES : `NO;
            `BRANCH_GREATER_EQUAL_UNSIGNED  : br_taken <= (in1 >= in2) ? `YES : `NO;
            `BRANCH_UNCONDITIONAL           : br_taken <= `YES;
            default                         : br_taken <= `NO;
        endcase
endmodule

module alu (
    input logic 
        [3:0]alu_op, 
        [31:0]inA, inB,
    output logic 
        [31:0]alu_out
    );
        
    always_comb begin
        alu_out = 0;
        case(alu_op)
            `ADD    : alu_out <= inA + inB;
            `SUB    : alu_out <= inA - inB;
            `SLL    : alu_out <= inA << inB[4:0];
            `SLT    : alu_out <= $signed(inA) < $signed(inB);
            `SLTU   : alu_out <= inA < inB;
            `XOR    : alu_out <= inA ^ inB;
            `SRL    : alu_out <= inA >> inB[4:0];
            `SRA    : alu_out <= inA >>> inB[4:0];
            `OR     : alu_out <= inA | inB;
            `AND    : alu_out <= inA & inB;
            `PASS_A : alu_out <= inA;
            `PASS_B : alu_out <= inB;
            `JALR   : alu_out <= (inA + inB) & ~32'h3;
            default : alu_out <= 0;
        endcase
    end
endmodule

module csr_reg_file (
    input logic clk, reset, csr_reg_wr, csr_reg_rd, is_mret,
    input logic mt_int, ext_int,
    input logic [11:0] csr_addr,
    input logic [31:0] pc, csr_wdata,
    output logic epc_taken,
    output logic [31:0] csr_rdata, epc_evec
    );

    // Define CSR registers
    logic [31:0] csr_mip_ff;
    logic [31:0] csr_mie_ff;
    logic [31:0] csr_mstatus_ff;
    logic [31:0] csr_mcause_ff;
    logic [31:0] csr_mtvec_ff;
    logic [31:0] csr_mepc_ff;

    // Define write flags for each CSR register
    logic csr_mip_wr_flag;
    logic csr_mie_wr_flag;
    logic csr_mstatus_wr_flag;
    logic csr_mcause_wr_flag;
    logic csr_mtvec_wr_flag;
    logic csr_mepc_wr_flag;

    logic interrupt_exception;

    // CSR MRET operation
    assign epc_taken = is_mret || (csr_mip_ff[7] && csr_mie_ff[7] && csr_mstatus_ff[3]) || (csr_mip_ff[11] && csr_mie_ff[11] && csr_mstatus_ff[3]);
    assign epc_evec = (is_mret) ? csr_mepc_ff : (!csr_mtvec_ff[0] ? {csr_mtvec_ff[31:2], 2'b00} : {csr_mtvec_ff[31:2], 2'b00} + (csr_mcause_ff[30:0] * 4)); // Vector and non-vector modes

    // CSR read operation
    always_comb begin
        csr_rdata = '0;  // Default to 0 if not reading any CSR register
        if (csr_reg_rd) begin
            case (csr_addr)
                `MSTATUS:   csr_rdata = csr_mstatus_ff; // Address for mstatus
                `MIE    :   csr_rdata = csr_mie_ff;     // Address for mie
                `MTVEC  :   csr_rdata = csr_mtvec_ff;   // Address for mtvec
                `MEPC   :   csr_rdata = csr_mepc_ff;    // Address for mepc
                `MCAUSE :   csr_rdata = csr_mcause_ff;  // Address for mcause
                `MIP    :   csr_rdata = csr_mip_ff;     // Address for mip
                default :   csr_rdata = '0;             // Default to 0 if address is unrecognized
            endcase
        end
    end

    // CSR write operation
    always_comb begin
        // Default all write flags to 0
        csr_mip_wr_flag     = 1'b0;
        csr_mie_wr_flag     = 1'b0;
        csr_mstatus_wr_flag = 1'b0;
        csr_mcause_wr_flag  = 1'b0;
        csr_mtvec_wr_flag   = 1'b0;
        csr_mepc_wr_flag    = 1'b0;

        if (csr_reg_wr) begin
            case (csr_addr)
                `MSTATUS:   csr_mstatus_wr_flag = 1'b1; // Address for mstatus
                `MIE    :   csr_mie_wr_flag     = 1'b1; // Address for mie
                `MTVEC  :   csr_mtvec_wr_flag   = 1'b1; // Address for mtvec
                `MEPC   :   csr_mepc_wr_flag    = 1'b1; // Address for mepc
                `MCAUSE :   csr_mcause_wr_flag  = 1'b1; // Address for mcause
                `MIP    :   csr_mip_wr_flag     = 1'b1; // Address for mip
                default: ;                              // No action if address is unrecognized
            endcase
        end
    end

    // Update CSR registers on positive edge of clock
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            csr_mip_ff     <= '0;
            csr_mie_ff     <= '0;
            csr_mstatus_ff <= '0;
            csr_mcause_ff  <= '0;
            csr_mtvec_ff   <= '0;
            csr_mepc_ff    <= '0;
            interrupt_exception <= `NO;
        end else begin
            // Standard CSR writes
            if (csr_mip_wr_flag)     csr_mip_ff     <= csr_wdata;
            if (csr_mie_wr_flag)     csr_mie_ff     <= csr_wdata;
            if (csr_mstatus_wr_flag) csr_mstatus_ff <= csr_wdata;
            if (csr_mcause_wr_flag)  csr_mcause_ff  <= csr_wdata;
            if (csr_mtvec_wr_flag)   csr_mtvec_ff   <= csr_wdata;
            if (csr_mepc_wr_flag)    csr_mepc_ff    <= csr_wdata;

            // Handle interrupts: set interrupt pending bits in mip register
            if (mt_int) csr_mip_ff[7] = 1'b1;
            if (ext_int) csr_mip_ff[11] = 1'b1;
            if (is_mret) interrupt_exception = `NO;
            // Interrupt handling logic for mcause and mepc
            if (csr_mip_ff[7] && csr_mie_ff[7] && csr_mstatus_ff[3] && !interrupt_exception) begin
                csr_mepc_ff   = pc;
                csr_mcause_ff = 32'h80000007;  // Machine timer interrupt cause (31 bit high and exception code 7)
                interrupt_exception = `YES;
            end
            else if (csr_mip_ff[11] && csr_mie_ff[11] && csr_mstatus_ff[3] && !interrupt_exception) begin
                csr_mepc_ff   = pc;
                csr_mcause_ff = 32'h8000000B;  // External interrupt cause (31 bit high and exception code 11)
                interrupt_exception = `YES;
            end
        end
    end
endmodule

module data_memory (
    input logic
        clk, reset, rd_en, wr_en,
        [1:0]wr_op, 
        [2:0]rd_op,
        [31:0]address, wdata,
    output logic
        [31:0]rdata
    );

    // Define a memory array with 64 32-bit entries
    logic [31:0] data [`DATA_MEMORY_SIZE-1:0];

    // Memory initialization
    always @(posedge reset) begin
        if (reset)
            $readmemh("data_memory.mem", data);
    end

    // Read memory contents (read operations)
    always_comb begin
        if (rd_en) begin
            logic [31:0] read_data;
            read_data = data[address[31:2]]; // Word-aligned address

            case (rd_op)
                `LOAD_BYTE: begin
                    case (address[1:0])
                        2'b00: rdata = {{24{read_data[7]}}, read_data[7:0]};
                        2'b01: rdata = {{24{read_data[15]}}, read_data[15:8]};
                        2'b10: rdata = {{24{read_data[23]}}, read_data[23:16]};
                        2'b11: rdata = {{24{read_data[31]}}, read_data[31:24]};
                    endcase
                end

                `LOAD_HALF: begin
                    case (address[1])
                        1'b0: rdata = {{16{read_data[15]}}, read_data[15:0]};
                        1'b1: rdata = {{16{read_data[31]}}, read_data[31:16]};
                    endcase
                end

                `LOAD_WORD: rdata = read_data;

                `LOAD_BYTE_UNSIGNED: begin
                    case (address[1:0])
                        2'b00: rdata = {24'b0, read_data[7:0]};
                        2'b01: rdata = {24'b0, read_data[15:8]};
                        2'b10: rdata = {24'b0, read_data[23:16]};
                        2'b11: rdata = {24'b0, read_data[31:24]};
                    endcase
                end

                `LOAD_HALF_UNSIGNED: begin
                    case (address[1])
                        1'b0: rdata = {16'b0, read_data[15:0]};
                        1'b1: rdata = {16'b0, read_data[31:16]};
                    endcase
                end
            endcase
            $display("address: %d, address[31:2]: %d, read_data: %h, rdata: %d, rd_op: %d, data: %p", address, address[31:2], read_data, rdata, rd_op, data);
        end 
        else begin
            rdata = 32'b0; // Set to zero if read is disabled
        end
    end

    // Memory write operations
    always_ff @(negedge clk) begin
        if (wr_en) begin
            case (wr_op)
                `STORE_BYTE: begin
                    case (address[1:0])
                        2'b00: data[address[31:2]][7:0] = wdata[7:0];
                        2'b01: data[address[31:2]][15:8] = wdata[7:0];
                        2'b10: data[address[31:2]][23:16] = wdata[7:0];
                        2'b11: data[address[31:2]][31:24] = wdata[7:0];
                    endcase
                end

                `STORE_HALF: begin
                    case (address[1])
                        1'b0: data[address[31:2]][15:0] = wdata[15:0];
                        1'b1: data[address[31:2]][31:16] = wdata[15:0];
                    endcase
                end

                `STORE_WORD: data[address[31:2]] = wdata;
            endcase
            // Optional: Write updated data to memory file (for debugging)
            $writememh("data_memory.mem", data);
        end
    end
endmodule


module RISCV_Processor (
    input logic 
        clk, reset, mt_int, ext_int,
    output logic 
        reg_wr_stg2, for_A, for_B, sel_A_stg2, sel_B_stg2, rd_en_stg2, wr_en_stg2, br_taken_stg2, reg_wr_stg3, wr_en_stg3, rd_en_stg3, stall_stg2, stall_stg3, flush, csr_reg_rd_stg2, csr_reg_rd_stg3, csr_reg_wr_stg2, csr_reg_wr_stg3, is_mret_stg2, is_mret_stg3, epc_taken,
        [1:0]wb_sel_stg2, wb_sel_stg3, wr_op_stg2, wr_op_stg3,
        [2:0]rd_op_stg2, rd_op_stg3, br_type_stg2,
        [3:0]alu_op_stg2, 
        [31:0]pc_stg1, inst_stg1, immediate, rd1, rd2, pre_inA, pre_inB, inA, inB, alu_out_stg2, rdata, wb, pc_stg2, pc_stg3, inst_stg2, inst_stg3, alu_out_stg3, wd_stg3, csr_wdata, csr_rdata, csr_addr, epc_evec
    );
    
    //Stage-1 Fetch
    program_counter PC_fetch (
        .clk(clk),
        .reset(reset),
        .br_taken(br_taken_stg2),
        .epc_taken(epc_taken),
        .jump_address(alu_out_stg2),
        .epc_evec(epc_evec),
        .pc(pc_stg1)
    );
    instruction_memory IM_fetch (
        .address(pc_stg1),
        .inst_machine_code(inst_stg1)
    );

    //Pipeline Stage-1 Registers
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG1_pc (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg2),
        .flush('0),
        .in_data(pc_stg1),
        .out_data(pc_stg2)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG1_inst (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg2),
        .flush(flush),
        .in_data(inst_stg1),
        .out_data(inst_stg2)
    ); 

    //Stage-2 Decode-Execute Control Registers
    control_signals CTRL_decode (
        .inst_machine_code(inst_stg2),
        .reg_wr(reg_wr_stg2),
        .sel_A(sel_A_stg2),
        .sel_B(sel_B_stg2),
        .rd_en(rd_en_stg2),
        .wr_en(wr_en_stg2),
        .wb_sel(wb_sel_stg2),
        .wr_op(wr_op_stg2),
        .br_type(br_type_stg2),
        .rd_op(rd_op_stg2),
        .alu_op(alu_op_stg2),
        .csr_reg_wr(csr_reg_wr_stg2),
        .csr_reg_rd(csr_reg_rd_stg2),
        .is_mret(is_mret_stg2)
    );

    //Pipeline Forwarding Unit
    forwarding_stall_flush_unit Pipeline_Forwarding_Stall_Flush_Unit (
        .clk(clk),
        .reset(reset),
        .inst_stg2(inst_stg2),
        .inst_stg3(inst_stg3),
        .reg_wr_stg3(reg_wr_stg3),
        .br_taken(br_taken_stg2),
        .for_A(for_A),
        .for_B(for_B),
        .stall_stg2(stall_stg2),
        .stall_stg3(stall_stg3),
        .flush(flush)
    );

    //Stage-2 Decode-Execute
    immediate_generator IMM_GEN_decode (
        .inst_machine_code(inst_stg2),
        .immediate_value(immediate)
    );
    register_file REG_FILE_decode (
        .clk(clk),
        .reset(reset),
        .reg_wr(reg_wr_stg3),
        .ra1(inst_stg2[19:15]),
        .ra2(inst_stg2[24:20]),
        .wa(inst_stg3[11:7]),
        .wdata_reg(wb),
        .rd1(rd1),
        .rd2(rd2)
    );
    branch_condition BRANCH_COND_execute (
        .in1(pre_inA),
        .in2(pre_inB),
        .br_type(br_type_stg2),
        .br_taken(br_taken_stg2)
    );
    // Selectors
    always_comb begin
        pre_inA <= for_A ? alu_out_stg3 : rd1;
        pre_inB <= for_B ? alu_out_stg3 : rd2;
        inA <= sel_A_stg2 ? pc_stg2 : pre_inA;   //A selector
        inB <= sel_B_stg2 ? immediate : pre_inB;   //B selector
    end

    alu ALU_execute (
        .alu_op(alu_op_stg2),
        .inA(inA),
        .inB(inB),
        .alu_out(alu_out_stg2)
    );

    //Pipeline Stage-2 Registers
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_pc (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(pc_stg2),
        .out_data(pc_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_inst (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(inst_stg2),
        .out_data(inst_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_alu_out (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(alu_out_stg2),
        .out_data(alu_out_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_wd (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(rd2),
        .out_data(wd_stg3)
    ); 
    //Pipeline Control Registers
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_reg_wr (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(reg_wr_stg2),
        .out_data(reg_wr_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_wr_en (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(wr_en_stg2),
        .out_data(wr_en_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_rd_en (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(rd_en_stg2),
        .out_data(rd_en_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(2)) Pipeline_CTRL_wb_sel (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(wb_sel_stg2),
        .out_data(wb_sel_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(2)) Pipeline_CTRL_wr_op (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(wr_op_stg2),
        .out_data(wr_op_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(3)) Pipeline_CTRL_rd_op (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(rd_op_stg2),
        .out_data(rd_op_stg3)
    ); 
    //CSR Registers
    pipeline_dynamic_registers #(.WIDTH(1)) CSR_csr_reg_wr (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(csr_reg_wr_stg2),
        .out_data(csr_reg_wr_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(1)) CSR_csr_reg_rd (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(csr_reg_rd_stg2),
        .out_data(csr_reg_rd_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(1)) CSR_is_mret (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(is_mret_stg2),
        .out_data(is_mret_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) CSR_wdata (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(pre_inA),
        .out_data(csr_wdata)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) CSR_addr (
        .clk(clk),
        .reset(reset),
        .stall(stall_stg3),
        .flush('0),
        .in_data(immediate),
        .out_data(csr_addr)
    );
    
    //Stage-3 Memory-Writeback
    data_memory DATA_MEMORY_memory (
        .clk(clk),
        .reset(rst),
        .rd_en(rd_en_stg3), 
        .wr_en(wr_en_stg3),
        .wr_op(wr_op_stg3), 
        .rd_op(rd_op_stg3),
        .address(alu_out_stg3),
        .wdata(wd_stg3),
        .rdata(rdata)
    );

    csr_reg_file CSR_REG_FILE (
        .clk(clk),
        .reset(reset),
        .csr_reg_wr(csr_reg_wr_stg3),
        .csr_reg_rd(csr_reg_rd_stg3),
        .is_mret(is_mret_stg3),
        .mt_int(mt_int),
        .ext_int(ext_int),
        .csr_addr(csr_addr[11:0]),
        .pc(pc_stg3), 
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),
        .epc_taken(epc_taken), 
        .epc_evec(epc_evec)
    );
    //Writeback
    always_comb
        case (wb_sel_stg3)
            0 : wb <= alu_out_stg3;
            1 : wb <= rdata;
            2 : wb <= pc_stg3 + 4;
            3 : wb <= csr_rdata;
        endcase
endmodule

module tb();
    logic clk, reset, for_A, for_B, sel_A_stg2, sel_B_stg2, br_taken_stg2, rd_en_stg2, rd_en_stg3, wr_en_stg2, wr_en_stg3, reg_wr_stg2, reg_wr_stg3, stall_stg2, stall_stg3, flush, csr_reg_rd_stg2, csr_reg_rd_stg3, csr_reg_wr_stg2, csr_reg_wr_stg3, is_mret_stg2, is_mret_stg3, epc_taken, mt_int, ext_int;
    logic [1:0]wb_sel_stg2, wb_sel_stg3, wr_op_stg2, wr_op_stg3;
    logic [2:0]rd_op_stg2, rd_op_stg3, br_type_stg2;
    logic [3:0]alu_op_stg2;
    logic [31:0]pc_stg1, pc_stg2, pc_stg3, inst_stg1, inst_stg2, inst_stg3, immediate, rd1, rd2, pre_inA, pre_inB, inA, inB, alu_out_stg2, alu_out_stg3, wb, rdata, wd_stg3, csr_wdata, csr_rdata, csr_addr, epc_evec;

    logic [5:0] ra1_stg1, ra2_stg1, wa_stg1, ra1_stg2, ra2_stg2, wa_stg2, ra1_stg3, ra2_stg3, wa_stg3;

    RISCV_Processor test (
        .clk(clk),
        .reset(reset),
        .reg_wr_stg2(reg_wr_stg2), 
        .for_A(for_A),
        .for_B(for_B),
        .sel_A_stg2(sel_A_stg2),
        .sel_B_stg2(sel_B_stg2),
        .rd_en_stg2(rd_en_stg2), 
        .wr_en_stg2(wr_en_stg2), 
        .wb_sel_stg2(wb_sel_stg2),
        .br_taken_stg2(br_taken_stg2),
        .wr_op_stg2(wr_op_stg2),
        .wr_op_stg3(wr_op_stg3),
        .rd_op_stg2(rd_op_stg2),
        .rd_op_stg3(rd_op_stg3),
        .br_type_stg2(br_type_stg2),
        .alu_op_stg2(alu_op_stg2),
        .pc_stg1(pc_stg1),
        .inst_stg1(inst_stg1),
        .immediate(immediate),
        .rd1(rd1),
        .rd2(rd2),
        .pre_inA(pre_inA),
        .pre_inB(pre_inB),
        .inA(inA),
        .inB(inB),
        .rdata(rdata), 
        .wb(wb),
        .pc_stg2(pc_stg2),
        .pc_stg3(pc_stg3),
        .inst_stg2(inst_stg2),
        .inst_stg3(inst_stg3),
        .stall_stg2(stall_stg2),
        .stall_stg3(stall_stg3),
        .flush(flush),
        .alu_out_stg2(alu_out_stg2),
        .alu_out_stg3(alu_out_stg3),
        .wd_stg3(wd_stg3),
        .reg_wr_stg3(reg_wr_stg3),
        .wr_en_stg3(wr_en_stg3),
        .rd_en_stg3(rd_en_stg3),
        .is_mret_stg2(is_mret_stg2),
        .is_mret_stg3(is_mret_stg3),
        .csr_reg_rd_stg2(csr_reg_rd_stg2),
        .csr_reg_rd_stg3(csr_reg_rd_stg3),
        .csr_reg_wr_stg2(csr_reg_wr_stg2),
        .csr_reg_wr_stg3(csr_reg_wr_stg3),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),
        .csr_addr(csr_addr),
        .mt_int(mt_int),
        .ext_int(ext_int),
        .epc_taken(epc_taken),
        .epc_evec(epc_evec),
        .wb_sel_stg3(wb_sel_stg3)
    );
    initial begin
        clk   <= 1;
        reset <= 1;
        mt_int <= 0;
        ext_int <= 0;
        #5;
        reset <= 0;
        #180;
        mt_int <= 1;
        #10;
        mt_int <= 0;
    end
    always #5 clk<=~clk;
    always @(negedge clk) begin
        case (inst_stg1[6:0]) // Extract the opcode (bits 6:0) from the instruction
            `R_TYPE_INST: $display("#time: %0t | %h: R-Type, Read Address 1: %h, Read Address 2: %h, Write Address: %h, func3: %b, func7: %b", 
                                    $time, inst_stg1, inst_stg1[19:15], inst_stg1[24:20], inst_stg1[11:7], inst_stg1[14:12], inst_stg1[31:25]);
            
            `I_TYPE_INST, `I_L_TYPE_INST, `I_JALR_TYPE_INST: $display("#time: %0t | %h: I-Type, Read Address 1: %h, Write Address: %h, Immediate Value: %0d, func3: %b", 
                                                                        $time, inst_stg1, inst_stg1[19:15], inst_stg1[11:7], {{20{inst_stg1[31]}}, inst_stg1[31:20]}, inst_stg1[14:12]);
            
            `S_TYPE_INST: $display("#time: %0t | %h: S-Type, Read Address 1: %h, Read Address 2: %h, Immediate Value: %0d, func3: %b", 
                                    $time, inst_stg1, inst_stg1[19:15], inst_stg1[24:20], {{20{inst_stg1[31]}}, inst_stg1[31:25], inst_stg1[11:7]}, inst_stg1[14:12]);
            
            `B_TYPE_INST: $display("#time: %0t | %h: B-Type, Read Address 1: %h, Read Address 2: %h, Immediate Value: %0d, func3: %b", 
                                    $time, inst_stg1, inst_stg1[19:15], inst_stg1[24:20], {{19{inst_stg1[31]}}, inst_stg1[31], inst_stg1[7], inst_stg1[30:25], inst_stg1[11:8], 1'b0}, inst_stg1[14:12]);
            
            `U_LUI_TYPE_INST, `U_AUIPC_TYPE_INST: $display("#time: %0t | %h: U-Type, Write Address: %h, Immediate Value: %0d", 
                                                    $time, inst_stg1, inst_stg1[11:7], {inst_stg1[31:12], 12'b0});
            
            `J_TYPE_INST: $display("#time: %0t | %h: J-Type, Write Address: %h, Immediate Value: %0d", 
                                    $time, inst_stg1, inst_stg1[11:7], {{11{inst_stg1[31]}}, inst_stg1[31], inst_stg1[19:12], inst_stg1[20], inst_stg1[30:21], 1'b0});
            
            default: $display("#time: %0t | %h: Unknown", $time, inst_stg1);
        endcase
    end

    always @(*) begin
        ra1_stg1 = inst_stg1[19:15];
        ra1_stg2 = inst_stg2[19:15];
        ra1_stg3 = inst_stg3[19:15];
        ra2_stg1 = inst_stg1[24:20];
        ra2_stg2 = inst_stg2[24:20];
        ra2_stg3 = inst_stg3[24:20];
        wa_stg1 = inst_stg1[11:7];
        wa_stg2 = inst_stg2[11:7];
        wa_stg3 = inst_stg3[11:7];
    end

endmodule