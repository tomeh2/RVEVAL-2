`timescale 1ns / 1ps

module fir_filter_tb(
        
    );
    
    logic [15:0] in, out;
    logic clk, reset;
    
    fir_filter #(.BITS_PER_SAMPLE(16),
                     .ORDER(4))
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
        
        #1us;
        in <= 16'h0100;
        #200ns;
        in <= 0;
    end initial;
endmodule
