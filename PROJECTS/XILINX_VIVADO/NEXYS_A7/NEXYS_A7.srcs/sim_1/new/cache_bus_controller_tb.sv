`timescale 1ns / 1ps

module cache_bus_controller_tb(

    );
    time T = 10ns;
    
    logic clk, reset;
    logic [31:0] bus_addr_write, bus_data_write, bus_addr_read, bus_data_read, fetch_address, writeback_address, fetched_cacheline_data;
    logic [23:0] fetched_cacheline_tag;
    logic [1:0] fetch_size, writeback_size;
    logic bus_stbr, bus_ackw, bus_ackr, fetch_cacheable, fetch_en, writeback_cacheable, writeback_en, fetched_cacheline_valid;
    logic [3:0] bus_stbw;
    
    always 
    begin
        clk <= 0;
        #(T/2);
        clk <= 1;
        #(T/2);
    end
    
    task t_putReadRequest(input logic [31:0] addr, input logic cacheable, input logic [1:0] size);
        fetch_address <= addr;
        fetch_cacheable <= cacheable;
        fetch_size <= size;
        fetch_en <= 1;
        
        @(posedge clk);
        #100ps;
        
        fetch_address <= 0;
        fetch_cacheable <= 0;
        fetch_size <= 0;
        fetch_en <= 0;
    endtask;
    
    task t_putWriteRequest();
    
    endtask;
    
    cache_bus_controller_2      #(.ADDRESS_WIDTH(32),
                                  .DATA_WIDTH(32),
                                  .ENTRY_SIZE_BYTES(4),
                                  .ENTRIES_PER_CACHELINE(4),
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
                                 .fetch_cacheable(fetch_cacheable),
                                 .fetch_size(fetch_size),
                                 .fetch_en(fetch_en),
                                 
                                 .fetched_cacheline_data(fetched_cacheline_data),
                                 .fetched_cacheline_tag(fetched_cacheline_tag),
                                 .fetched_cacheline_valid(fetched_cacheline_valid),
                                 
                                 .writeback_address(writeback_address),
                                 .writeback_size(writeback_size),
                                 .writeback_cacheable(writeback_cacheable),
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
        
        t_putReadRequest(32'h0000_0000, 1, 2'h00);
        t_putReadRequest(32'h1000_0000, 1, 2'h00);
        t_putReadRequest(32'h2000_0000, 1, 2'h00);
        t_putReadRequest(32'h3000_0000, 1, 2'h00);
        t_putReadRequest(32'h4000_0000, 1, 2'h00);
        t_putReadRequest(32'h5000_0000, 1, 2'h00);
        #(T * 50);
        bus_data_read <= 32'hAAAA_AAAA;
        t_putReadRequest(32'h0000_0010, 0, 2'h00);
        t_putReadRequest(32'h1000_0020, 0, 2'h01);
        t_putReadRequest(32'h2000_0030, 0, 2'h10);
        t_putReadRequest(32'h3000_0040, 0, 2'h10);
        
    end initial;
endmodule
