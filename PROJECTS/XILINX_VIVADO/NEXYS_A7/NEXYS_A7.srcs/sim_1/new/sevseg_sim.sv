`timescale 1ns / 1ps

module sevseg_sim(

    );
    
    logic [7:0] anodes, cathodes;
    
    uut sevseg_interface(.anodes(),
                         .cathodes(),
                         
                         .bus_wdata(),
                         .bus_addr(),
                         .bus_stbw(),
                         .bus_ack(),
                         .bus_cyc(),
                         
                         .clk_bus(),
                         .clk_ref(),
                         .reset());
endmodule
