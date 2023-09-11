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
    
    typedef struct packed
    {
        logic [31:0] generated_address;
        logic generated_address_valid;
        logic [31:0] generated_data;
        logic generated_data_valid;
        logic [2:0] sq_tag;
        logic [2:0] lq_tag;
        logic is_store;
    } lsu_spec_input;
    
    typedef struct packed
    {
        logic [31:0] pc_low_bits;
        logic [3:0] instr_tag;
        logic [5:0] phys_dest_reg;
        logic [31:0] data;
        logic [31:0] target_addr;
        logic [3:0] branch_mask; 
        logic branch_taken;
        logic branch_mispredicted;
        logic is_jalr;
        logic is_jal;
                                        
        logic valid;
    } cdb_single;
    
    typedef struct packed
    {
        logic [31:0] read_data;
        logic read_ready;
        logic [5:0] read_phys_dest_reg;
        logic [3:0] instr_tag;
        logic [1:0] read_size;
        logic [2:0] lq_tag;
        logic read_hit; 
        logic read_miss;
        logic write_ready;
        logic write_hit;
        logic write_miss;
                                        
        logic loaded_cacheline_tag_valid;
        logic [23 - 1:0] loaded_cacheline_tag;
    } cache_out;
    
    typedef struct packed
    {
        cdb_single cdb_data;
        cdb_single cdb_branch;
    } cdb;
    
    uop_in_type uop_inst;
    rob_head rob_head_inst;
    cdb_single cdb_inst;
    lsu_spec_input lsu_spec_input_inst;
    cache_out cache_out_inst;
    
    task t_reset();
        reset = 1;
        @(posedge clk);
        #100ps;
        reset = 0;
    endtask;
    
    task t_putStore(input logic [1:0] size = 2'b10);
        uop_inst.pc <= 32'h0000_0000;
        uop_inst.operation_type <= 3'b011;
        uop_inst.operation_select <= {8'b00000000, size};
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
    
    task t_putLoad(input logic [1:0] size = 2'b10);
        uop_inst.pc <= 32'h0000_0000;
        uop_inst.operation_type <= 3'b010;
        uop_inst.operation_select <= {8'b00000000, size};
        uop_in_valid <= 1;
        
        @(posedge clk);
        #100ps;
        uop_in_valid <= 0;
    endtask;
    
    task t_putBranch(input logic [3:0] brmask);
        uop_inst.pc <= 32'h0000_0000;
        uop_inst.operation_type <= 3'b001;
        uop_inst.operation_select <= 10'b0000000010;
        uop_inst.branch_mask <= brmask;
        uop_in_valid <= 1;
        
        @(posedge clk);
        #100ps;
        uop_inst.branch_mask <= 0;
        uop_in_valid <= 0;
    endtask;
    
    task t_finishBranch(input logic [3:0] brmask, input logic mispred);
        cdb_inst.branch_mispredicted <= 1;
        cdb_inst.branch_mask <= brmask;
        cdb_inst.valid <= 1;
        
        @(posedge clk);
        #100ps;
        cdb_inst.valid <= 0;
    endtask;
    
    task t_genAddrDataStore(input logic [2:0] sq_tag, input logic [31:0] addr, input logic [31:0] data);
        lsu_spec_input_inst.generated_address <= addr;
        lsu_spec_input_inst.generated_data <= data;
        lsu_spec_input_inst.generated_address_valid <= 1;
        lsu_spec_input_inst.generated_data_valid <= 1;
        lsu_spec_input_inst.sq_tag <= sq_tag;
        lsu_spec_input_inst.is_store <= 1;
        
        @(posedge clk);
        #100ps;
        lsu_spec_input_inst.generated_address <= 0;
        lsu_spec_input_inst.generated_data <= 0;
        lsu_spec_input_inst.generated_address_valid <= 0;
        lsu_spec_input_inst.generated_data_valid <= 0;
        lsu_spec_input_inst.sq_tag <= 0;
        lsu_spec_input_inst.is_store <= 0;
    endtask;
    
    task t_genAddrLoad(input logic [2:0] lq_tag, input logic [31:0] addr);
        lsu_spec_input_inst.generated_address <= addr;
        lsu_spec_input_inst.generated_address_valid <= 1;
        lsu_spec_input_inst.is_store <= 0;
        lsu_spec_input_inst.generated_data_valid <= 0;
        lsu_spec_input_inst.generated_data <= 0;
        lsu_spec_input_inst.lq_tag <= lq_tag;
        
        @(posedge clk);
        #100ps;
        lsu_spec_input_inst.lq_tag <= 0;
        lsu_spec_input_inst.generated_address_valid <= 0;
    endtask;
    
    task t_cacheLoadDone();
        cache_out_inst.read_data <= 32'hF0F0_B0B0;
        cache_out_inst.instr_tag <= 5;
        cache_out_inst.read_phys_dest_reg <= 12;
        cache_out_inst.read_ready <= 1;
        cache_out_inst.read_size <= 0;
        cache_out_inst.lq_tag <= 0;
        
        @(posedge clk);
        #100ps;
        cache_out_inst.read_data <= 32'h0000_0000;
        cache_out_inst.instr_tag <= 0;
        cache_out_inst.read_phys_dest_reg <= 0;
        cache_out_inst.read_ready <= 0;
        cache_out_inst.read_size <= 0;
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
        uop_inst <= 0;
        cdb_inst <= 0;
        lsu_spec_input_inst <= 0;
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
        
        #(T * 50);
        t_putStore();
        t_putStore();
        t_putStore();
        t_putBranch(4'b0001);
        t_putStore();
        t_putStore();
        t_putStore();
        t_retireStore(0);
        t_retireStore(1);
        t_finishBranch(4'b0001, 0);
        t_retireStore(2);
        
        #(T * 50);
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        
        // TAIL > HEAD SCENARIO
        #(T * 50);
        t_reset();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        
        // TAIL < HEAD SCENARIO
        #(T * 50);
        t_reset();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_retireStore(0);
        t_retireStore(1);
        t_retireStore(2);
        t_retireStore(3);
        t_retireStore(4);
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        t_putStore();
        t_putLoad();
        
        // TEST LOAD/STORE ADDR/DATA GEN
        #(T * 50);
        t_reset();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putStore();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_putLoad();
        t_genAddrDataStore(2, 32'h3000_0000, 32'h3333_3333);
        t_genAddrDataStore(0, 32'h1000_0000, 32'h1111_1111);
        t_genAddrDataStore(1, 32'h2000_0000, 32'h2222_2222);
        t_genAddrDataStore(3, 32'h4000_0000, 32'h4444_4444);
        t_genAddrLoad(2, 32'h3000_0000);
        t_genAddrLoad(0, 32'h1000_0000);
        t_genAddrLoad(1, 32'h2000_0000);
        t_genAddrLoad(3, 32'h4000_0000);
        #(T * 5);
        t_retireStore(3);
        t_retireStore(2);
        t_retireStore(1);
        t_retireStore(0);
        
        
        // ADDRESS MATCHING TESTS
        #(T * 50);
        t_reset();
        t_putStore(2'b10);
        t_genAddrDataStore(0, 32'h0000_0000, 32'h1111_1111);
        t_putLoad(2'b10);
        t_genAddrLoad(0, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b10);
        t_genAddrLoad(1, 32'h0000_0004);                        // DONT MATCH
        t_putLoad(2'b01);
        t_genAddrLoad(2, 32'h0000_0002);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b01);
        t_genAddrLoad(3, 32'h0000_0004);                        // DONT MATCH
        t_putLoad(2'b00);
        t_genAddrLoad(4, 32'h0000_0001);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b00);
        t_genAddrLoad(5, 32'h0000_0004);                        // DONT MATCH
        
        #(T * 50);
        t_reset();
        t_putStore(2'b01);
        t_genAddrDataStore(0, 32'h0000_0000, 32'h1111_1111);
        t_putLoad(2'b10);
        t_genAddrLoad(0, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b10);
        t_genAddrLoad(1, 32'h0000_0004);                        // DONT MATCH
        t_putLoad(2'b01);
        t_genAddrLoad(2, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b01);
        t_genAddrLoad(3, 32'h0000_0002);                        // DONT MATCH
        t_putLoad(2'b00);
        t_genAddrLoad(4, 32'h0000_0001);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b00);
        t_genAddrLoad(5, 32'h0000_0002);                        // DONT MATCH
        
        #(T * 50);
        t_reset();
        t_putStore(2'b00);
        //t_genAddrDataStore(0, 32'h0000_0000, 32'h1111_1111);
        t_putLoad(2'b10);
        t_genAddrLoad(0, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b10);
        t_genAddrLoad(1, 32'h0000_0004);                        // DONT MATCH
        t_putLoad(2'b01);
        t_genAddrLoad(2, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b01);
        t_genAddrLoad(3, 32'h0000_0002);                        // DONT MATCH
        t_putLoad(2'b00);
        t_genAddrLoad(4, 32'h0000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        t_putLoad(2'b00);
        t_genAddrLoad(5, 32'h0000_0001);                        // DONT MATCH
        
        #(T * 50);
        t_reset();
        t_putStore(2'b10);
        t_putLoad(2'b10);
        t_genAddrLoad(0, 32'h3000_0000);                        // MATCH ADDR OF SQ ENTRY 0
        #(T * 50);
        t_genAddrDataStore(0, 32'h3000_0000, 32'h3333_3333);
        t_retireStore(0);
        
        #(T * 50);
        t_reset();
        t_cacheLoadDone();
        t_cacheLoadDone();
        
        #1ms;
    end initial;
    
    load_store_unit_spec lsu_inst(.uop_in(uop_inst),
                                  .uop_in_valid(uop_in_valid),
                                  
                                  .rob_head_in(rob_head_inst),
                                  .cdb_branch(cdb_inst),
                                  .addr_data_gen_in(lsu_spec_input_inst),
                                  
                                  .from_cache(cache_out_inst),
                                  
                                  .clk(clk),
                                  .reset(reset));
    
endmodule
