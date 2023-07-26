`timescale 1ns / 1ps

module fir_filter_tb(
        
    );
    
    logic [15:0] in, out;
    logic clk, reset;
    
    fir_filter #(.BITS_PER_SAMPLE(16),
                 .BITS_FRACTION(12),
                     .ORDER(64))
               uut (.input_signal(in),
                    .output_signal(out),
                    
                    .clk(clk),
                    .reset(reset));
                 
    assign #10ns clk = ~clk;
                    
    initial
    begin
        clk <= 0;
        in <= 0;
        
        reset <= 1;
        #20ns;
        reset <= 0;
        
        #5us;
        in <= 16'h1000;
        #20ns;
        in <= 0;
    end initial;
endmodule
