`timescale 1ns / 1ps

module dcache_tb(

    );
    logic[31:0] bus_data_read, bus_addr_read, read_addr_1, write_addr_1, write_data_1, read_data_out_1;
    logic bus_ackr, bus_stbr, bus_ackw, read_valid_1, read_ready_1, write_valid_1, write_ready_1, read_miss_1, read_hit_1, write_miss_1, write_hit_1, reset, clk;
    logic[1:0] write_size_1;
   
    reg [31:0] mem[15:0];
   
    assign bus_ackw = 1;
    dcache uut (
              .bus_data_read(bus_data_read),
              .bus_addr_read(bus_addr_read),
              .bus_ackr(bus_ackr),
              .bus_ackw(bus_ackw),
              .bus_stbr(bus_stbr),
              
              .read_addr_1(read_addr_1),
              .read_tag_1(0),
              .read_valid_1(read_valid_1),
              .read_ready_1(read_ready_1),
              .read_data_out_1(read_data_out_1),
              
              .write_addr_1(write_addr_1),
              .write_data_1(write_data_1),
              .write_size_1(write_size_1),
              .write_tag_1(0),
              .write_valid_1(write_valid_1),
              .write_ready_1(write_ready_1),
              
              .read_hit_1(read_hit_1),
              .read_miss_1(read_miss_1),
              .read_miss_tag_1(),
              
              .write_hit_1(write_hit_1),
              .write_miss_1(write_miss_1),
              .write_miss_tag_1(),
              
               .clk(clk),
               .reset(reset));
               
    task t_reset();
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
    endtask;
               
    task t_read_req(input [31:0] addr, input [31:0] expected_data, input block);
        read_addr_1 = addr;
        read_valid_1 = 1;
        wait (read_ready_1 == 1);
        @(posedge clk);
        #1;
        read_addr_1 = 0;
        read_valid_1 = 0;
        @(posedge clk);
        #1;
        if (read_hit_1 == 1) begin
            assert (read_data_out_1 == expected_data) else
                $fatal("Expected: %h | Got: %h", expected_data, read_data_out_1);
        end;
    endtask;
    
    task t_write_req(input [31:0] addr, input [31:0] data, input [1:0] write_size);
        write_addr_1 = addr;
        write_data_1 = data;
        write_size_1 = write_size;
        write_valid_1 = 1;
        wait (write_ready_1 == 1);
        @(posedge clk);
        #1;
        write_addr_1 = 0;
        write_data_1 = 0;
        write_size_1 = 0;
        write_valid_1 = 0;
        @(posedge clk);
        #1;
    endtask;
    
    task t_write_req_nodelay(input [31:0] addr, input [31:0] data, input [1:0] write_size);
        write_addr_1 = addr;
        write_data_1 = data;
        write_size_1 = write_size;
        write_valid_1 = 1;
        wait (write_ready_1 == 1);
        @(posedge clk);
        #1;
        write_addr_1 = 0;
        write_data_1 = 0;
        write_size_1 = 0;
        write_valid_1 = 0;
    endtask;
    
    task t_read_req_nowait(input [31:0] addr);

    endtask;

    
    always @(posedge clk) begin
        bus_ackr <= !bus_ackr && bus_stbr;
    end
    
    assign bus_data_read = mem[bus_addr_read[5:2]];
    
    task t_run_dcache();
        t_read_req('h0000_0000, 'h0000_0000, 0);    // MISS
        #200;
        t_read_req('h0000_0004, 'h1111_1111, 0);    // HIT
        t_read_req('h0000_0008, 'h2222_2222, 0);
        t_read_req('h0000_000C, 'h3333_3333, 0);
        t_read_req('h0000_0010, 'h4444_4444, 0);
        #200;
        t_read_req('h0000_0014, 'h5555_5555, 0);
        t_read_req('h0000_0018, 'h6666_6666, 0);
        t_read_req('h0000_001C, 'h7777_7777, 0);
        #200;
        t_write_req_nodelay('h0000_0000, 'hF0F0_F0F0, 2);
        t_write_req_nodelay('h0000_0004, 'hBABA_BABA, 2);
        
        t_read_req('h0000_004, 'hBABA_BABA, 0);
        
        t_write_req_nodelay('h0000_0008, 'h1234_5678, 2);
        t_write_req_nodelay('h0000_000C, 'h9ABC_DEF0, 2);
        
        t_read_req('h0000_000C, 'h9ABC_DEF0, 0);
        t_read_req('h0000_0100, 'h0000_0000, 0);
        
        t_write_req_nodelay('h0000_0104, 'h1234_ABCD, 2);
        
        // Cause eviction
        t_read_req('h0000_1000, 'h0000_0000, 0);
        
        // Write to noncacheable address
        t_write_req_nodelay('hFFFF_1000, 'h1234_ABCD, 2);
        #1000;
        t_read_req('hFFFF_2000, 'h0000_0000, 0);
    endtask;

    initial begin
        $readmemh("../../../../icache_tb_mem_init.mem", mem);
        clk = 0;
        read_addr_1 = 0;
        read_valid_1 = 0;
        write_addr_1 = 0;
        write_size_1 = 0;
        write_data_1 = 0;
        write_valid_1 = 0;
        
        t_reset();
        t_run_dcache();
        
        #1000;
        
        $finish;
    end
    
    always #10 clk = ~clk;
endmodule



















