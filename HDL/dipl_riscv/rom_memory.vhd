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
use ieee.numeric_std.all;
use STD.TEXTIO.ALL;

entity rom_memory is
    generic(
        DATA_WIDTH_BITS : integer := 32;
        ADDR_WIDTH_BITS : integer := 12
    );
    port(
        data : out std_logic_vector(DATA_WIDTH_BITS - 1 downto 0);
        addr : in std_logic_vector(ADDR_WIDTH_BITS - 1 downto 0);
        en : in std_logic;
        ack : out std_logic;
        reset : in std_logic;
        clk : in std_logic
    );
end rom_memory;

architecture rtl of rom_memory is
    type ram_type is array (2 ** ADDR_WIDTH_BITS - 1 downto 0) of std_logic_vector (DATA_WIDTH_BITS - 1 downto 0);

    impure function init_ram_hex return ram_type is
        file text_file : text open read_mode is "../../../firmware.hex";
        variable text_line : line;
        variable ram_content : ram_type;
        variable temp : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 2 ** ADDR_WIDTH_BITS - 1 loop
                readline(text_file, text_line);
                hread(text_line, temp);

                ram_content(i) := temp;
				--for j in 0 to 3 loop
                --    ram_content(i)(8 * (j + 1) - 1 downto 8 * j) := temp(8 * (4 - j) - 1 downto 8 * (3 - j));
                --end loop;
            end loop;    
 
        return ram_content;
    end function;
    
    signal ack_i : std_logic;
    signal mem : ram_type := init_ram_hex;

begin
    process (clk)
    begin
        if (rising_edge(clk)) then
            if (en = '1') then
                data <= mem(to_integer(unsigned(addr)));
            end if;
        end if;
    end process;
    

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                ack_i <= '0';
            else
                ack_i <= en and not ack_i; 
            end if;
        end if;
    end process;
    
    ack <= ack_i;

end rtl;
