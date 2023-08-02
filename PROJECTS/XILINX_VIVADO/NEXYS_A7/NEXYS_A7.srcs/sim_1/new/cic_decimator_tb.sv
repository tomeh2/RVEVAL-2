`timescale 1ns / 1ps

module cic_decimator_tb(

    );
    logic [15:0] in, out;
    logic clk, reset, valid;
    int sr = 3072000;
    time t = 1000000000.0 / sr;
    
    cic_decimator #(.BITS_PER_SAMPLE(16),
                    .DELAY(1),   
                    .ORDER(2),
                    .DECIMATION_FACTOR(64))
               uut (.signal_in(in),
                    .signal_out(out),
                    .signal_out_valid(valid),
                    
                    .clk(clk),
                    .reset(reset));
                 
    assign #(t / 2) clk = ~clk;
               
    int fd;     
    initial
    begin
        fd = $fopen("C:/users/pc/desktop/test_sim.raw", "wb");
        clk <= 0;
        in <= 0;
        
        reset <= 1;
        #t;
        reset <= 0;
        
        @(posedge clk);
        in <= 16'h0001;
        #(t * 10000);
        in <= 0;
    end initial;
    
    always @(posedge clk) begin
        if (valid == 1) begin
            $fwrite(fd, "%c", out[7:0]);
            $fwrite(fd, "%c", out[15:8]);
            $display("%u", out);
        end
    end
    
endmodule
