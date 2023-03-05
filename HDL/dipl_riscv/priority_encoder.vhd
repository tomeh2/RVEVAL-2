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

entity priority_encoder is
    generic(
        NUM_INPUTS : integer range 1 to 8192;
        HIGHER_INPUT_HIGHER_PRIO : boolean
    );
    port(
        d : in std_logic_vector(NUM_INPUTS - 1 downto 0);
        q : out std_logic_vector(integer(ceil(log2(real(NUM_INPUTS)))) - 1 downto 0);
        valid : out std_logic
    );
end priority_encoder;

architecture rtl of priority_encoder is
    constant D_ZERO : std_logic_vector(NUM_INPUTS - 1 downto 0) := (others => '0');
begin
    process(d)
        variable output_value : integer;
    begin
        output_value := 0;
        if (d = D_ZERO) then
            q <= (others => '0');
            valid <= '0';
            output_value := 0;
        else
            if (HIGHER_INPUT_HIGHER_PRIO = true) then
                for k in 0 to NUM_INPUTS - 1 loop
                    if (d(k) = '1') then
                        output_value := k;
                    end if;
                end loop;
            else
                for k in NUM_INPUTS - 1 downto 0 loop
                    if (d(k) = '1') then
                        output_value := k;
                    end if;
                end loop;
            end if;
            valid <= '1';
        end if;
        
        q <= std_logic_vector(to_unsigned(output_value, integer(ceil(log2(real(NUM_INPUTS))))));
    end process;

end rtl;
