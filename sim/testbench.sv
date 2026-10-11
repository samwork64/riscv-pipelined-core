module RISCV_Processor (
    input logic 
        clk, reset,
    output logic 
        reg_wr_stg2, sel_A_stg2, sel_B_stg2, rd_en_stg2, wr_en_stg2, br_taken_stg2, reg_wr_stg3, wr_en_stg3, rd_en_stg3,
        [1:0]wb_sel_stg2, wb_sel_stg3, wr_op_stg2,
        [2:0]rd_op_stg2, br_type_stg2,
        [3:0]alu_op_stg2, 
        [31:0]pc_stg1, inst_stg1, immediate, rd1, rd2, inA, inB, alu_out_stg2, rdata, wb, pc_stg2, pc_stg3, inst_stg2, inst_stg3, alu_out_stg3, wd_stg3 
    );
    
    //Stage-1 Fetch
    program_counter PC_fetch (
        .clk(clk),
        .reset(reset),
        .br_taken(br_taken_stg2),
        .jump_address(alu_out_stg2),
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
        .in_data(pc_stg1),
        .out_data(pc_stg2)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG1_inst (
        .clk(clk),
        .reset(reset),
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
        .alu_op(alu_op_stg2)
    );

    //Pipeline Control Registers
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_reg_wr (
        .clk(clk),
        .reset(reset),
        .in_data(reg_wr_stg2),
        .out_data(reg_wr_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_wr_en (
        .clk(clk),
        .reset(reset),
        .in_data(wr_en_stg2),
        .out_data(wr_en_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(1)) Pipeline_CTRL_rd_en (
        .clk(clk),
        .reset(reset),
        .in_data(rd_en_stg2),
        .out_data(rd_en_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(2)) Pipeline_CTRL_wb_sel (
        .clk(clk),
        .reset(reset),
        .in_data(wb_sel_stg2),
        .out_data(wb_sel_stg3)
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
        .in1(rd1),
        .in2(rd2),
        .br_type(br_type_stg2),
        .br_taken(br_taken_stg2)
    );
    always_comb inA <= sel_A ? pc_stg2 : rd1;   //A selector
    always_comb inB <= sel_B ? immediate : rd2;   //B selector
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
        .in_data(pc_stg2),
        .out_data(pc_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_inst (
        .clk(clk),
        .reset(reset),
        .in_data(inst_stg2),
        .out_data(inst_stg3)
    ); 
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_alu_out (
        .clk(clk),
        .reset(reset),
        .in_data(alu_out_stg2),
        .out_data(alu_out_stg3)
    );
    pipeline_dynamic_registers #(.WIDTH(32)) Pipeline_STG2_wd (
        .clk(clk),
        .reset(reset),
        .in_data(rd),
        .out_data(wd_stg3)
    ); 

    //Stage-3 Memory-Writeback
    data_memory DATA_MEMORY_memory (
        .clk(clk),
        .reset(rst),
        .rd_en(rd_en_stg3), 
        .wr_en(wr_en_stg3),
        .wr_op(wr_op_stg2), 
        .rd_op(rd_op_stg2),
        .address(alu_out_stg3),
        .wdata(wd_stg3),
        .rdata(rdata)
    );
    always_comb
        case (wb_sel_stg3)
            0 : wb <= alu_out_stg3;
            1 : wb <= rdata;
            2 : wb <= pc_stg3 + 4;
        endcase
endmodule

module tb();
    logic clk, reset, sel_A_stg2, sel_B_stg2, br_taken_stg2, rd_en_stg2, rd_en_stg3, wr_en_stg2, wr_en_stg3, reg_wr_stg2, reg_wr_reg2;
    logic [1:0]wb_sel_stg2, wb_sel_stg3, wr_op;
    logic [2:0]rd_op_stg2, br_type;
    logic [3:0]alu_op;
    logic [31:0]pc_stg1, pc_stg2, pc_stg3, inst_stg1, inst_stg2, inst_stg3, immediate, rd1, rd2, inA, inB, alu_out_stg2, wb, alu_out_stg3, rdata, wd_stg3;
    RISCV_Processor test (
        .clk(clk),
        .reset(reset),
        .reg_wr_stg2(reg_wr_stg2),
        .sel_A_stg2(sel_A_stg2),
        .sel_B_stg2(sel_B_stg2),
        .rd_en_stg2(rd_en_stg2), 
        .wr_en_stg2(wr_en_stg2), 
        .wb_sel_stg2(wb_sel_stg2),
        .br_taken_stg2(br_taken_stg2),
        .wr_op_stg2(wr_op_stg2),
        .rd_op_stg2(rd_op_stg2),
        .br_type_stg2(br_type_stg2),
        .alu_op_stg2(alu_op_stg2),
        .pc_stg1(pc_stg1),
        .inst_stg1(inst_stg1),
        .immediate(immediate),
        .rd1(rd1),
        .rd2(rd2),
        .inA(inA),
        .inB(inB),
        .rdata(rdata), 
        .wb(wb),
        .pc_stg2(pc_stg2),
        .pc_stg3(pc_stg3),
        .inst_stg2(inst_stg2),
        .inst_stg3(inst_stg3),
        .alu_out_stg2(alu_out_stg2),
        .alu_out_stg3(alu_out_stg3),
        .wd_stg3(wd_stg3),
        .reg_wr_stg3(reg_wr_stg3),
        .wr_en_stg3(wr_en_stg3),
        .rd_en_stg3(rd_en_stg3),
        .wb_sel_stg3(wb_sel_stg3)
    );
    initial begin
    clk   <= 1;
    reset <= 1;
    #5;
    reset <= 0;
    #100;
    reset <= 1;
    end
    always #5 clk<=~clk;
endmodule