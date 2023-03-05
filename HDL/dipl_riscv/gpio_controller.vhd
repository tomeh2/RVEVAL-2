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

entity gpio_controller is
    port(
        -- ========== BUS SIGNALS ==========
        bus_raddr : in std_logic_vector(3 downto 0);
        bus_waddr : in std_logic_vector(3 downto 0);
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_rdata : out std_logic_vector(31 downto 0);
        bus_rstrb : in std_logic;
        bus_wstrb : in std_logic_vector(3 downto 0);
        bus_ackr : out std_logic;
        bus_ackw : out std_logic;
        -- =================================
        
        -- ============= I/O SIGNALS ==============
        gpio_o : out std_logic_vector(31 downto 0);
        gpio_i : in std_logic_vector(31 downto 0);
        -- ========================================
        
        clk : in std_logic;
        reset : in std_logic
    );
end gpio_controller;

architecture rtl of gpio_controller is
    signal gpio_o_reg : std_logic_vector(31 downto 0);
    signal gpio_i_reg : std_logic_vector(31 downto 0);
    
    signal bus_ackw_i : std_logic;
    signal bus_ackr_i : std_logic;
begin
    bus_rdata <= gpio_i_reg;
    gpio_o <= gpio_o_reg;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                gpio_o_reg <= (others => '0');
                gpio_i_reg <= (others => '0');
            else
                gpio_i_reg <= gpio_i;
                
                case bus_waddr is
                    when X"0" =>
                        if (bus_wstrb(0) = '1') then
                            gpio_o_reg <= bus_wdata;
                        end if;
                    when others =>
                        
                end case;
            end if;
        end if;
    end process;
    
    bus_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
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













