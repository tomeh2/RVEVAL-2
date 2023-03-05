--===============================================================================
--MIT License

--Copyright (c) 2022 Tomislav Harmina

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.
--===============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- TO DO LIST
-- 1) EU 0 Stalls its dispatch pipeline way to often without the real need to do so which causes the CPU to often stall due to the scheduler often being full. Make it accept instructions more agressively
-- 2) RAW hazards could still cause issues since the scheduler won't dispatch dependent instructions until the result is produced. This problem could be worsened is EU 0 becomes high latency, so cant agressively pipeline.
-- Dispatching instructions before they are ready (if the result is about to be produced) might make sense. Reminds of more traditional forwarding.
-- 3) Instruction cache (Current WIP); 
-- 4) Data cache implementation & LSU rework (will probably need to happen together)
-- 5) Bus rework & I/O unit improvement

-- FIXME: ICACHE needs a way to invalidate certain (or all) cachelines in the event that they become stale (FENCE.I?)
-- FIXME: UOP FIFO will report as not ready if it has only one element inside

-- NOTE: Patched an already known issue in the ROB that was previously present in the decoded uop FIFO aswell. The problem would appear in a very specific case when 
-- the FIFO was supposed to empty in the next cycle, but another entry gets written in the same cycle. That could cause the the FIFO to give old value in memory as a data output
-- instead of the required new one and could cause the FIFO to completely skip a value. Cause is the "smart" prediction which enables the FIFOs to sustain 1 read per cycle 
-- while they are implemented in memories with a 1-cycle delay. Consider a replacing with a properly tested FIFO since more issues may be present. 

entity top is
    port(
        LED : out std_logic_vector(15 downto 0);
        CLK100MHZ : in std_logic;
        BTNC : in std_logic;
        BTNL : in std_logic;
        BTNR : in std_logic;
        
        UART_TXD_IN : in std_logic;
        UART_RXD_OUT : out std_logic
        
    );
end top;

architecture strucutral of top is
    component clk_wiz_0
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      -- Status and control signals
      reset             : in     std_logic;
      clk_in1           : in     std_logic
     );
    end component;
    
    signal clk_cpu : std_logic;
    signal clk_dbg : std_logic;
    
    signal gpio_o : std_logic_vector(31 downto 0);
    signal gpio_i : std_logic_vector(31 downto 0);
begin
    gpio_i(31 downto 2) <= (others => '0');
    gpio_i(1) <= BTNL;
    gpio_i(0) <= BTNR;
    LED <= gpio_o(15 downto 0);

    cpu : entity work.cpu(structural)
          port map(uart_rx => UART_TXD_IN,
                   uart_tx => UART_RXD_OUT,
                   uart_rts => '0',
                   
                   gpio_i => gpio_i,
                   gpio_o => gpio_o,
          
                   clk_cpu => clk_cpu,
                   reset_cpu => BTNC);
                   
    your_instance_name : clk_wiz_0
        port map ( 
       -- Clock out ports  
        clk_out1 => clk_cpu,
       -- Status and control signals                
        reset => '0',
        -- Clock in ports
        clk_in1 => CLK100MHZ);

end strucutral;
