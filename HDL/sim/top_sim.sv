module top_sim(

    );
    
    logic clk, clk_pdm, reset, uart_tx, uart_rx, pdm_in;
    logic[31:0] gpio_o;
    
    soc uut(.clk(clk),
            .clk_pdm(clk_pdm),
            .reset(reset),
            
            .pdm_input(pdm_in),
            
            .gpio_i(0),
            .gpio_o(gpio_o),
            
            .uart_tx(uart_tx),
            .uart_rx(uart_rx));
            
    assign #5ns clk = ~clk;        // 50 MHz
    
    always @(posedge clk) begin
        clk_pdm <= ~clk_pdm;
    end 
    
    always @(posedge clk_pdm) begin
        pdm_in <= ~pdm_in;
    end 
    
    task uart_send(logic[7:0] data);
        uart_rx = 0;
        //#1us;
        //#85ns;
        #1000ns;
        for (int i = 0; i < 8; i++)
        begin
            uart_rx = data[i];
            //#1us;
            //#85ns;
            #1000ns;
        end 
        uart_rx = 1;
        
        //#1us;
        //#85ns;
        #1000ns;
    endtask;
    
    initial begin
        clk = 0;
        reset = 1;
        
        #50ns;
        
        reset = 0;
    end initial;
    
    reg[7:0] data;
    initial
    begin
        int fd;
        fd = $fopen("D:/Programs/cygwin64/home/Tomi/github/f32c/src/examples/sevseg/sevseg.srec", "rb");
        if (!fd)
            $display("Could not open file!");
        else
            $display("File opened successfully!");

        
        uart_rx = 1;
        
        //$readmemb("F:\Programs\cygwin64\home\Tomi\github\f32c\src\bench\dhry\dhry.srec", ldr);
        
        #1ms;

        for (int i = 0; i < 30000; i++)
        begin
            //uart_send('b00101101);
            $fread(data, fd);
            uart_send(data);
        end 
    end initial;
    
    initial
    begin
        clk_pdm <= 0;
        pdm_in <= 0;
    end initial;
endmodule
