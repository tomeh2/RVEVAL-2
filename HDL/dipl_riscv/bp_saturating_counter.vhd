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
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use WORK.PKG_CPU.ALL;

entity bp_saturating_counter is
    port(
        bp_in : in bp_in_type;
        bp_out : out bp_out_type;
        stall : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end bp_saturating_counter;

architecture rtl of bp_saturating_counter is
    constant INDEX_BITS : integer := integer(ceil(log2(real(BP_ENTRIES))));

    type sat_cntrs_type is array (BP_ENTRIES - 1 downto 0) of std_logic_vector(1 downto 0);
    signal sat_cntrs : sat_cntrs_type; 
    
    signal read_addr : std_logic_vector(INDEX_BITS - 1 downto 0);
    signal write_addr : std_logic_vector(INDEX_BITS - 1 downto 0);
begin
    read_addr <= bp_in.fetch_addr(INDEX_BITS + 1 downto 2);
    write_addr <= bp_in.put_addr(INDEX_BITS + 1 downto 2);

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to BP_ENTRIES - 1 loop
                    sat_cntrs(i) <= BP_2BST_INIT_VAL;
                end loop;
            else
                if (bp_in.put_en = '1') then
                    case (sat_cntrs(to_integer(unsigned(write_addr)))) is
                        when "00" =>
                            if (bp_in.put_outcome = '0') then
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "00";
                            else 
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "01";
                            end if;
                        when "01" => 
                            if (bp_in.put_outcome = '0') then
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "00";
                            else 
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "10";
                            end if;
                        when "10" => 
                            if (bp_in.put_outcome = '0') then
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "01";
                            else 
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "11";
                            end if;
                        when "11" =>
                            if (bp_in.put_outcome = '0') then
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "10";
                            else 
                                sat_cntrs(to_integer(unsigned(write_addr))) <= "11";
                            end if;
                        when others => 
                    end case;
                end if;
            end if;
            
            if (stall = '0') then
                bp_out.predicted_outcome <= sat_cntrs(to_integer(unsigned(read_addr)))(1);
            end if;
        end if;
    end process;

end rtl;
