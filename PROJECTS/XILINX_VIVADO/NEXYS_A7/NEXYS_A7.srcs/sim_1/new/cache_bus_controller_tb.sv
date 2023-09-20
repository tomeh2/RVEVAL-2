`timescale 1ns / 1ps

module cache_bus_controller_tb(

    );
    time T = 10ns;
    
    logic clk, reset;
    logic [31:0] bus_addr_write, bus_data_write, bus_addr_read, bus_data_read, fetch_address, writeback_address, fetched_cacheline_data;
    logic [127:0] writeback_data;
    logic [23:0] fetched_cacheline_tag;
    logic [1:0] fetch_data_size, writeback_data_size;
    logic [2:0] fetch_size, writeback_size;
    logic bus_stbr, bus_ackw, bus_ackr, fetch_cacheable, fetch_en, writeback_cacheable, writeback_en, fetched_cacheline_valid;
    logic [3:0] bus_stbw;
    
    always 
    begin
        clk <= 0;
        #(T/2);
        clk <= 1;
        #(T/2);
    end
    
    task t_putReadRequest(input logic [31:0] addr, input logic [1:0] data_size, input logic [2:0] size = 3'b100);
        fetch_address <= addr;
        fetch_size <= size;
        fetch_data_size <= data_size;
        fetch_en <= 1;
        
        @(posedge clk);
        #100ps;
        
        fetch_address <= 0;
        fetch_size <= 0;
        fetch_en <= 0;
    endtask;
    
    task t_putWriteRequest(input logic [31:0] addr, input logic [127:0] data, input logic [1:0] data_size, input logic [2:0] size = 3'b100);
        writeback_address <= addr;
        writeback_data <= data;
        writeback_size <= size;
        writeback_data_size <= data_size;
        writeback_en <= 1;
        
        @(posedge clk);
        #100ps;
        writeback_address <= 0;
        writeback_data <= 0;
        writeback_size <= 0;
        writeback_data_size <= 0;
        writeback_en <= 0;
    endtask;
    
    cache_bus_controller_2      #(.ADDRESS_WIDTH(32),
                                  .DATA_WIDTH(32),
                                  .BYTES_PER_ENTRY(4),
                                  .MAX_BURST_LENGTH(4),
                                  .TAG_BITS(24),
                                  
                                  .READ_FIFO_DEPTH(4),
                                  .WRITE_FIFO_DEPTH(4))
                      cbc_inst  (.bus_addr_write(bus_addr_write),
                                 .bus_data_write(bus_data_write),
                                 .bus_addr_read(bus_addr_read),
                                 .bus_data_read(bus_data_read),
                                 .bus_stbw(bus_stbw),
                                 .bus_stbr(bus_stbr),
                                 .bus_ackw(bus_ackw),
                                 .bus_ackr(bus_ackr),
                                 
                                 .fetch_address(fetch_address),
                                 .fetch_burst_length(fetch_size),
                                 .fetch_data_size(fetch_data_size),
                                 .fetch_en(fetch_en),
                                 
                                 .fetched_cacheline_data(fetched_cacheline_data),
                                 .fetched_cacheline_tag(fetched_cacheline_tag),
                                 .fetched_cacheline_valid(fetched_cacheline_valid),
                                 
                                 .writeback_address(writeback_address),
                                 .writeback_data(writeback_data),
                                 .writeback_burst_length(writeback_size),
                                 .writeback_data_size(writeback_data_size),
                                 .writeback_en(writeback_en),
                                 
                                 .clk(clk),
                                 .reset(reset));
    
    
    initial
    begin
        reset <= 1;
        #(T * 10);
        reset <= 0;
        bus_ackr <= 1;
        bus_ackw <= 1;    
        bus_data_read <= 32'hF0F0_FFFF;
        
        t_putReadRequest(32'h0000_0000, 2'h00);
        t_putReadRequest(32'h1000_0000, 2'h00);
        t_putReadRequest(32'h2000_0000, 2'h00);
        t_putReadRequest(32'h3000_0000, 2'h00);
        t_putReadRequest(32'h4000_0000, 2'h00);
        t_putReadRequest(32'h5000_0000, 2'h00);
        #(T * 50);
        bus_data_read <= 32'hAAAA_AAAA;
        t_putReadRequest(32'h0000_0010, 2'b00);
        t_putReadRequest(32'h1000_0020, 2'b01);
        t_putReadRequest(32'h2000_0030, 2'b10);
        t_putReadRequest(32'h3000_0040, 2'b10);
        #(T * 50);
        reset <= 1;
        #(T * 50);
        reset <= 0;
        t_putReadRequest(32'h0000_0010, 2'b10, 3'b100);
        t_putReadRequest(32'h1000_0020, 2'b10, 3'b011);
        t_putReadRequest(32'h2000_0030, 2'b10, 3'b010);
        t_putReadRequest(32'h3000_0040, 2'b10, 3'b001);
        t_putReadRequest(32'h3000_0050, 2'b10, 3'b000);
        #(T * 50);
        reset <= 1;
        #(T * 50);
        reset <= 0;
        t_putWriteRequest(32'h0000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        t_putWriteRequest(32'h1000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        t_putWriteRequest(32'h2000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        t_putWriteRequest(32'h3000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        t_putWriteRequest(32'h4000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        t_putWriteRequest(32'h5000_0000, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b100);
        #(T * 50);
        reset <= 1;
        #(T * 50);
        reset <= 0;
        t_putWriteRequest(32'h3000_0030, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b10, 3'b001);
        #(T * 20);
        t_putWriteRequest(32'h4000_0040, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b01, 3'b001);
        t_putWriteRequest(32'h4000_0042, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b01, 3'b001);
        #(T * 20);
        t_putWriteRequest(32'h5000_0050, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b00, 3'b001);
        t_putWriteRequest(32'h5000_0051, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b00, 3'b001);
        t_putWriteRequest(32'h5000_0052, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b00, 3'b001);
        t_putWriteRequest(32'h5000_0053, 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef, 2'b00, 3'b001);
        
    end initial;
endmodule
