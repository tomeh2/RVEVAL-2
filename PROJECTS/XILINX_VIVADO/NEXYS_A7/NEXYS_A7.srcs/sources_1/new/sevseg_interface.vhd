--===============================================================================
--MIT License

--Copyright (c) 2023 Tomislav Harmina

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

entity sevseg_interface is
    generic(
        REFRESH_RATE : integer;
        REFRESH_CLK_FREQ : integer
    );
    port(
        anodes : out std_logic_vector(7 downto 0);
        cathodes : out std_logic_vector(7 downto 0);
    
        bus_wdata : in std_logic_vector(31 downto 0);
        bus_addr : in std_logic_vector(31 downto 0);
        bus_stbw : in std_logic_vector(3 downto 0);
        bus_ack : out std_logic;
        bus_cyc : in std_logic;
        
        clk_bus : in std_logic;
        clk_ref : in std_logic;
        reset : in std_logic
    );
end sevseg_interface;

architecture rtl of sevseg_interface is
    type data_regs_type is array (7 downto 0) of std_logic_vector(7 downto 0);
    signal data_regs : data_regs_type;
    signal anode_reg : std_logic_vector(7 downto 0);
    
    signal active_anode_cntr_reg : unsigned(2 downto 0);
    signal update_cntr_reg : unsigned(31 downto 0);
    
    signal i_bus_ready : std_logic;
    
    constant UPDATE_CNTR_REG_TRIG_VAL : unsigned := to_unsigned(REFRESH_CLK_FREQ / (REFRESH_RATE * 8), 32);
begin
    -- BUS INTERFACE
    process(clk_bus)
    begin
        if (rising_edge(clk_bus)) then
            if (reset = '1') then
                data_regs <= (others => (others => '1'));
            else
                if (bus_addr(2) = '0' and bus_cyc = '1') then
                    case bus_stbw is
                        when "0001" => data_regs(0) <= bus_wdata(7 downto 0);
                        when "0010" => data_regs(1) <= bus_wdata(15 downto 8);
                        when "0100" => data_regs(2) <= bus_wdata(23 downto 16);
                        when "1000" => data_regs(3) <= bus_wdata(31 downto 24);
                        when others => 
                    end case;
                elsif (bus_addr(2) = '1' and bus_cyc = '1') then
                    case bus_stbw is
                        when "0001" => data_regs(4) <= bus_wdata(7 downto 0);
                        when "0010" => data_regs(5) <= bus_wdata(15 downto 8);
                        when "0100" => data_regs(6) <= bus_wdata(23 downto 16);
                        when "1000" => data_regs(7) <= bus_wdata(31 downto 24);
                        when others => 
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    -- REFRESH CONTROL REGISTERS
    process(clk_ref)
    begin
        if (rising_edge(clk_ref)) then
            if (reset = '1') then
                update_cntr_reg <= (others => '0');
                active_anode_cntr_reg <= (others => '0');
                
                anode_reg <= X"FE";
            else
                if (update_cntr_reg = UPDATE_CNTR_REG_TRIG_VAL) then
                    update_cntr_reg <= (others => '0');
                    active_anode_cntr_reg <= active_anode_cntr_reg + 1;
                    
                    anode_reg(7 downto 1) <= anode_reg(6 downto 0);
                    anode_reg(0) <= anode_reg(7);
                else
                    update_cntr_reg <= update_cntr_reg + 1;
                end if;
                
            end if;
        end if;
    end process;
    
    process(all)
    begin
        cathodes <= data_regs(to_integer(active_anode_cntr_reg));
        anodes <= anode_reg;
    end process;
    
    bus_cntrl : process(clk_bus)
    begin
        if (rising_edge(clk_bus)) then
            if (reset = '1') then
                i_bus_ready <= '0';
            else
                i_bus_ready <= bus_cyc and not i_bus_ready;
            end if;
        end if;
    end process;
    
    bus_ack <= i_bus_ready;

end rtl;






