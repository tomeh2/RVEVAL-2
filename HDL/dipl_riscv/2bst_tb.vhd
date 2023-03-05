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
use WORK.PKG_CPU.ALL;

entity bst_tb is

end bst_tb;

architecture Behavioral of bst_tb is
    signal clk : std_logic;
    signal reset : std_logic;

    constant T : time := 20ns;
    
    signal bp_in : bp_input_type;
    signal bp_out : bp_output_type;
begin
    reset <= '1', '0' after T * 2;

    process
    begin
        clk <= '0';
        wait for T / 2;
        clk <= '1';
        wait for T / 2;
    end process;
    
    uut : entity work.bp_saturating_counter(rtl)
          port map(bp_in => bp_in,
                   bp_out => bp_out,
                   
                   clk => clk,
                   reset => reset);

    process
    begin
        bp_in.fetch_addr <= "1000";
        bp_in.put_addr <= (others => '0');
        bp_in.put_outcome <= '0';
        bp_in.put_en <= '0';
        
        wait for T * 50;
        
        bp_in.fetch_addr <= (others => '0');
        bp_in.put_addr <= "1000";
        bp_in.put_outcome <= '1';
        bp_in.put_en <= '0';
        
        wait for T * 20;
        
        bp_in.fetch_addr <= (others => '0');
        bp_in.put_addr <= "1000";
        bp_in.put_outcome <= '1';
        bp_in.put_en <= '1';
        
        wait for T * 20;
        
        bp_in.fetch_addr <= "1000";
        bp_in.put_addr <= "1000";
        bp_in.put_outcome <= '1';
        bp_in.put_en <= '0';
        
        wait for T * 20;
        
        bp_in.fetch_addr <= (others => '0');
        bp_in.put_addr <= "1000";
        bp_in.put_outcome <= '0';
        bp_in.put_en <= '1';
        
        wait for T * 20;
    end process;

end Behavioral;
