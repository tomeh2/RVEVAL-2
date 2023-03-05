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
use IEEE.NUMERIC_STD.ALL;

entity ram_memory is
    generic(
        SIZE_BYTES : integer
    );
    port(
        -- ========== BUS SIGNALS ==========
        bus_raddr : in std_logic_vector(integer(ceil(log2(real(SIZE_BYTES)))) - 1 downto 0);
        bus_waddr : in std_logic_vector(integer(ceil(log2(real(SIZE_BYTES)))) - 1 downto 0);
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_rstrb : in std_logic;
        bus_wstrb : in std_logic_vector(3 downto 0);
        bus_ackr : out std_logic;
        bus_ackw : out std_logic;
        -- =================================
        
        -- ========== CONTROL SIGNALS ==========
        clk : in std_logic;
        resetn : in std_logic
        -- =====================================
    );
end ram_memory;

architecture rtl of ram_memory is
    constant NB_COL : integer := 4;
    constant COL_WIDTH : integer := 8;
    constant BUS_ADDR_BITS : integer := integer(ceil(log2(real(SIZE_BYTES))));

    type ram_type is array (0 to SIZE_BYTES / 4 - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);

    signal ram : ram_type;
    
    signal bus_ackw_i : std_logic;
    signal bus_ackr_i : std_logic;
begin
    ram_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (bus_rstrb = '1' and bus_ackr_i = '0') then
                bus_rdata <= ram(to_integer(unsigned(bus_raddr(BUS_ADDR_BITS - 1 downto 2))));
            end if;
                    
            for i in 0 to NB_COL - 1 loop
                if (bus_wstrb(i) = '1' and bus_ackw_i = '0') then
                    ram(to_integer(unsigned(bus_waddr(BUS_ADDR_BITS - 1 downto 2))))((i + 1) * COL_WIDTH - 1 downto i * COL_WIDTH) <= bus_wdata((i + 1) * COL_WIDTH - 1 downto i * COL_WIDTH);
                end if;
            end loop;
        end if;
    end process;

    bus_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (resetn = '0') then
                bus_ackr_i <= '0';
                bus_ackw_i <= '0';
            else
                bus_ackw_i <= '1' when bus_wstrb /= X"0" and bus_ackw_i = '0' else '0';
                bus_ackr_i <= bus_rstrb and not bus_ackr_i;
            end if;
        end if;
    end process;

    bus_ackw <= bus_ackw_i;
    bus_ackr <= bus_ackr_i;

end rtl;