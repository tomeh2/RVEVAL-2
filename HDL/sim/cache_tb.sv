`timescale 1ns / 1ps

module cache_tb(

    );
    
    time T = 10ns;
    
    logic clk, reset;
    
    typedef struct packed
    {
        logic [31:0] address;
        logic [31:0] data;
        logic [1:0] size;
        logic [1:0] cacheop;
        logic valid;
    } write_uop;
    
    typedef struct packed
    {
        logic [31:0] address;
        logic [1:0] size;
        logic valid;
    } read_uop;
    
    write_uop write_uop_inst;
    read_uop read_uop_inst;
    
    cache_2             #(.DATA_WIDTH(32),
                         .ADDRESS_WIDTH(32),
                         .ENTRY_SIZE_BYTES(4),
                         .ENTRIES_PER_CACHELINE(4),
                         .NUM_SETS(8),
                         .ASSOCIATIVITY(2),
                         .IS_BLOCKING(0))
             cache_inst (.read_input_port(read_uop_inst),
                        .write_input_port(write_uop_inst),
                        
                        .reset(reset),
                        .clk(clk));
    
    task t_putRead_uOP(input logic [31:0] addr, input logic [1:0] size);
        read_uop_inst.address <= addr;
        read_uop_inst.size <= size;
        read_uop_inst.valid <= 1;
        
        @(posedge clk);
        #100ps;
        
        read_uop_inst.address <= 0;
        read_uop_inst.size <= 0;
        read_uop_inst.valid <= 0;
    endtask;
    
    task t_putWrite_uOP(input logic [31:0] addr, input logic [31:0] data, input logic [1:0] size);
        write_uop_inst.address <= addr;
        write_uop_inst.data <= data;
        write_uop_inst.size <= size;
        write_uop_inst.valid <= 1;
        
        @(posedge clk);
        #100ps;
        
        write_uop_inst.address <= 0;
        write_uop_inst.data <= 0;
        write_uop_inst.size <= 0;
        write_uop_inst.valid <= 0;
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
        reset <= 1;
        #(T * 10);
        reset <= 0;
        
        t_putWrite_uOP(32'h0000_0000, 32'hFFFF_FFFF, 2'b10);
    end initial;
    
endmodule



















