`timescale 1ns / 1ps

import pkg_cpu::*;

module load_store_unit_spec_tb(
        
    );
    time T = 10ns;
    
    logic clk, reset;
    logic uop_in_valid;
    
    typedef struct packed
    {
        logic [31:0] pc;
        logic [2:0] operation_type;
        logic [9:0] operation_select;
        logic [10:0] csr;
        logic [31:0] immediate;
        
        logic [4:0] arch_src_reg_1_addr;
        logic [4:0] arch_src_reg_2_addr;
        logic [4:0] arch_dest_reg_addr;
        
        logic [5:0] phys_src_reg_1_addr;
        logic [5:0] phys_src_reg_2_addr;
        logic [5:0] phys_dest_reg_addr;
        
        logic [4:0] instr_tag;
        logic [2:0] stq_tag;
        logic [2:0] ldq_tag;
        
        logic [3:0] branch_mask;
        logic [3:0] speculated_branches_mask;
        logic branch_predicted_outcome;
    } uop_in_type;
    
    typedef struct packed
    {
        logic [2:0] operation_type;
        logic [4:0] arch_dest_reg;
        logic [5:0] phys_dest_reg;
        logic [2:0] sq_tag;
        logic retire;
    } rob_head;
    
    uop_in_type uop_inst;
    rob_head rob_head_inst;
    
    task t_reset();
        reset = 1;
        @(posedge clk);
        #100ps;
        reset = 0;
    endtask;
    
    task t_putStore();
        uop_inst.pc <= 32'h0000_0000;
        uop_inst.operation_type <= 3'b011;
        uop_inst.operation_select <= 10'b0000000010;
        uop_in_valid <= 1;
        
        @(posedge clk);
        #100ps;
        uop_in_valid <= 0;
    endtask;
    
    task t_retireStore(input logic [2:0] sq_tag);
        rob_head_inst.operation_type <= 3'b011;
        rob_head_inst.sq_tag <= sq_tag;
        rob_head_inst.retire <= 1;
        
        @(posedge clk);
        #100ps;
        rob_head_inst.retire <= 0;
    endtask;
    
    always 
    begin
        clk <= 0;
        #(T/2);
        clk <= 1;
        #(T/2);
    end
    
    initial 
    begin
        t_reset();
        @(posedge clk);
        // FILL
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();       //OVERFILL
        t_putStore();       //OVERFILL
        
        // RETIRE ALL STORES
        t_retireStore(1);
        t_retireStore(2);
        t_retireStore(3);
        t_retireStore(4);
        t_retireStore(5);
        t_retireStore(6);
        t_retireStore(7);
        #(T * 5);
        t_retireStore(0);
        
        
        #1us;
    end initial;
    
    load_store_unit_spec lsu_inst(.uop_in(uop_inst),
                                  .uop_in_valid(uop_in_valid),
                                  
                                  .rob_head_in(rob_head_inst),
                                  .cdb_in(0),
                                  
                                  .clk(clk),
                                  .reset(reset));
    
endmodule
