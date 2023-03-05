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
use IEEE.MATH_REAL.ALL;

entity barrel_shifter_2 is
    generic(
        DATA_WIDTH : integer
    );
    port(
        data_in : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_out : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        
        shift_amount : in std_logic_vector(integer(ceil(log2(real(DATA_WIDTH)))) - 1 downto 0);
        shift_arith : in std_logic;
        shift_direction : in std_logic
    );
end barrel_shifter_2;

architecture rtl of barrel_shifter_2 is
    type intermediate_results_type is array (integer(ceil(log2(real(DATA_WIDTH)))) - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    
    signal intermediate_results : intermediate_results_type;
begin
    process(shift_amount, shift_direction, shift_arith, data_in, intermediate_results)
    begin
        if (shift_amount(0) = '1') then
            if (shift_direction = '0') then
                if (shift_arith = '0') then
                    intermediate_results(0)(DATA_WIDTH - 1) <= '0';
                    intermediate_results(0)(DATA_WIDTH - 2 downto 0) <= data_in(DATA_WIDTH - 1 downto 1);
                else
                    intermediate_results(0)(DATA_WIDTH - 1) <= data_in(DATA_WIDTH - 1);
                    intermediate_results(0)(DATA_WIDTH - 2 downto 0) <= data_in(DATA_WIDTH - 1 downto 1);
                end if;
            else
                intermediate_results(0)(DATA_WIDTH - 1 downto 1) <= data_in(DATA_WIDTH - 2 downto 0);
                intermediate_results(0)(0) <= '0';
            end if;
        else
            intermediate_results(0) <= data_in;
        end if;
        
        
    
        for i in 1 to integer(ceil(log2(real(DATA_WIDTH)))) - 1 loop
            if (shift_amount(i) = '1') then
                if (shift_direction = '0') then
                    if (shift_arith = '0') then
                        intermediate_results(i)(DATA_WIDTH - 1 downto DATA_WIDTH - 2 ** i) <= (others => '0');
                        intermediate_results(i)(DATA_WIDTH - 1 - 2 ** i downto 0) <= intermediate_results(i - 1)(DATA_WIDTH - 1 downto 2 ** i);
                    else
                        intermediate_results(i)(DATA_WIDTH - 1 downto DATA_WIDTH - 2 ** i) <= (others => intermediate_results(i - 1)(DATA_WIDTH - 1));
                        intermediate_results(i)(DATA_WIDTH - 1 - 2 ** i downto 0) <= intermediate_results(i - 1)(DATA_WIDTH - 1 downto 2 ** i);
                    end if;
                else
                    intermediate_results(i)(DATA_WIDTH - 1 downto 2 ** i) <= intermediate_results(i - 1)(DATA_WIDTH - 1 - 2 ** i downto 0);
                    intermediate_results(i)(2 ** i - 1 downto 0) <= (others => '0');
                end if;
            else
                intermediate_results(i) <= intermediate_results(i - 1);
            end if;
        end loop;
    end process;
    
    data_out <= intermediate_results(integer(ceil(log2(real(DATA_WIDTH)))) - 1);

end rtl;
