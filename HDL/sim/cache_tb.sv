`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/22/2022 01:45:53 PM
// Design Name: 
// Module Name: dcache_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cache_tb(

    );
    logic[127:0] cacheline_write;
    logic[153:0] cacheline_read;
    logic[31:0] data_read, addr_1, data_1, write_addr, miss_cacheline_addr, bus_data_read, bus_addr_read;
    logic is_write, clear_pipeline, stall, valid_1, hit, miss, cacheline_valid, clk, reset, bus_ackr, bus_stbr;
    logic[1:0] write_size_1;
    reg [31:0] mem[15:0];
   
    cache #(.ADDR_SIZE_BITS(32),
              .ENTRY_SIZE_BYTES(4),
              .ENTRIES_PER_CACHELINE(4),
              .ASSOCIATIVITY(2),
              .NUM_SETS(16),
              .ENABLE_WRITES(1),
              .ENABLE_FORWARDING(0),
              .IS_BLOCKING(0))
             uut (
              .bus_data_read(bus_data_read),
              .bus_addr_read(bus_addr_read),
              .bus_ackr(bus_ackr),
              .bus_stbr(bus_stbr),
              .cacheline_read_1(cacheline_read),
              .data_read(data_read),
              .addr_1(addr_1),
              .data_1(data_1),
              .is_write_1(is_write),
              .write_size_1(write_size_1),
              .clear_pipeline(clear_pipeline),
              .stall(stall),
              .valid_1(valid_1),
              .hit(hit),
              .miss(miss),
              .cacheline_valid(cacheline_valid),
              
               .clk(clk),
               .reset(reset));
               
    task t_reset();
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
    endtask;
               
    task t_read_req(input [31:0] addr, input [31:0] expected_data, input block);
        addr_1 = addr;
        valid_1 = 1;
        @(posedge clk);
        #1;
        valid_1 = 0;
        addr_1 = 0;
        @(posedge clk);
        #1;
        if (block == 1) begin
            wait(hit == 1);
        end;
        if (hit == 1) begin
            assert(data_read == expected_data) else 
                $fatal("Expected Data: %h | Got Data: %h", expected_data, data_read);
        end;
        @(posedge clk);
        #1;
    endtask;
    
    task t_write_req(input [31:0] addr, input [31:0] data, input [1:0] write_size);
        addr_1 = addr;
        data_1 = data;
        is_write = 1;
        valid_1 = 1;
        write_size_1 = write_size;
        @(posedge clk);
        #1;
        is_write = 0;
        valid_1 = 0;
        addr_1 = 0;
        write_size_1 = 0;
        @(posedge clk);
        #1;
        @(posedge clk);
        #1;
    endtask;
    
    task t_read_req_nowait(input [31:0] addr);
        addr_1 = addr;
        valid_1 = 1;
        @(posedge clk);
        #1;
        valid_1 = 0;
        addr_1 = 0;
    endtask;
    
    task t_read_chkdata(input [31:0] expected_data);
        wait(hit == 1 || miss == 1);
        if (hit == 1) begin
            assert(data_read == expected_data) else 
                $fatal("Expected Data: %h | Got Data: %h", expected_data, data_read);
        end;
        @(posedge clk);
        #1;
    endtask;
    
    always @(posedge clk) begin
        bus_ackr <= !bus_ackr && bus_stbr;
    end
    
    assign bus_data_read = mem[bus_addr_read[5:2]];
    
    task t_run_dcache();
        t_read_req('h0000_0000, 'h0000_0000, 0);
        t_read_req('h0000_0004, 'h1111_1111, 0);
        t_read_req('h0000_0008, 'h2222_2222, 0);
        t_read_req('h0000_000C, 'h3333_3333, 0);
        t_read_req('h0000_0010, 'h4444_4444, 0);
        t_read_req('h0000_0014, 'h5555_5555, 0);
        t_read_req('h0000_0018, 'h6666_6666, 0);
        t_read_req('h0000_001C, 'h7777_7777, 0);
        
        #1000;
        t_read_req_nowait('h0000_0010);
        t_read_req_nowait('h0000_0014);
        t_read_req_nowait('h0000_0018);
        t_read_req_nowait('h0000_001C);
        #1000;
        
        t_write_req('h0000_0000, 'hF0F0_F0F0, 'b10);
        t_write_req('h0000_0004, 'hF0F0_F0F0, 'b10);
        t_write_req('h0000_0008, 'hF0F0_F0F0, 'b10);
        t_write_req('h0000_000C, 'hF0F0_F0F0, 'b10);
    endtask;
    
    task t_run_icache();
        t_read_req('h0000_0000, 'h0000_0000, 1);
        t_read_req('h0000_0004, 'h1111_1111, 1);
        t_read_req('h0000_0008, 'h2222_2222, 1);
        t_read_req('h0000_000C, 'h3333_3333, 1);
    endtask;
    
    initial begin
        $readmemh("../../../../icache_tb_mem_init.mem", mem);
        clk = 0;
        is_write = 0;
        stall = 0;
        write_addr = 0;
        valid_1 = 0;
        clear_pipeline = 0;
        write_size_1 = 0;
        
        t_reset();
        t_run_dcache();
    end
    
    always #10 clk = ~clk;
endmodule



















