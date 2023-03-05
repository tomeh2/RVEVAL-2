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

use work.pkg_axi.all;

entity axi_bus_controller_simple is
    generic(
        NUM_MASTERS : integer
    );
    port(
        -- SIGNALS FROM MASTERS
        master_bus_requests : in std_logic_vector(3 downto 0);
        
        -- SIGNALS FROM AND TO INTERCONNECT
        bus_address : in std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        master_sel : out std_logic_vector(3 downto 0);
        slave_sel : out std_logic_vector(3 downto 0);

        bus_disable : out std_logic;
        
        -- OTHER SIGNALS
        clk : in std_logic;
        reset : in std_logic
    );
end axi_bus_controller_simple;

architecture rtl of axi_bus_controller_simple is
    type arbiter_state_type is (IDLE,
                                SLAVE_DECODE,
                                BUS_GRANTED);

    signal curr_master_counter_reg : unsigned(3 downto 0);
    signal curr_master_counter_next : unsigned(3 downto 0);
    signal curr_master_counter_en : std_logic;
    signal curr_master_counter_reg_reset : std_logic;
    
    signal slave_sel_reg : std_logic_vector(3 downto 0);
    signal slave_sel_next : std_logic_vector(3 downto 0);
    signal slave_sel_en : std_logic;
    
    signal arbiter_state_reg : arbiter_state_type;
    signal arbiter_state_reg_next : arbiter_state_type;
begin
    -- ========== READ ARBITRATION AND DECODING ==========
    with curr_master_counter_reg select curr_master_counter_reg_reset <=
        '1' when to_unsigned(NUM_MASTERS - 1, 4),
        '0' when others;
    
    counter_update : process(clk)
    begin
        if (rising_edge(clk)) then
            if (curr_master_counter_reg_reset = '1' or reset = '0') then
                curr_master_counter_reg <= (others => '0');
            elsif (curr_master_counter_en = '1') then
                curr_master_counter_reg <= curr_master_counter_next;
            end if;
        end if;
    end process;
    
    curr_master_counter_next <= curr_master_counter_reg + 1;
    
    address_decoder : process(bus_address)
    begin
        if (bus_address(31 downto 12) = X"0000_0")  then             -- Slave 1 at addresses 0000_0000 - 0000_0FFF
            slave_sel_next <= "0000";
        elsif (bus_address(31 downto 12) = X"0000_1") then           -- Slave 2 at addresses 0000_1000 - 0000_1FFF
            slave_sel_next <= "0001";
        elsif (bus_address(31 downto 12) = X"0000_2") then           -- Slave 3 at addresses 0000_2000 - 0000_2FFF
            slave_sel_next <= "0010";
        else
            slave_sel_next <= "1111";
        end if;
    end process;

    state_reg_update : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '0') then  
                arbiter_state_reg <= IDLE;
            else
                arbiter_state_reg <= arbiter_state_reg_next;
            end if;
        end if;
    end process;
    
    read_slave_sel_reg_update : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '0') then  
                slave_sel_reg <= "1111";
            elsif (slave_sel_en = '1') then
                slave_sel_reg <= slave_sel_next;
            end if;
        end if;
    end process;

    next_state_proc : process(arbiter_state_reg, master_bus_requests, curr_master_counter_reg)
    begin
        if (arbiter_state_reg = IDLE) then
            if (master_bus_requests(to_integer(curr_master_counter_reg)) = '1') then
                arbiter_state_reg_next <= SLAVE_DECODE;
            else
                arbiter_state_reg_next <= IDLE;
            end if;
        elsif (arbiter_state_reg = SLAVE_DECODE) then
            arbiter_state_reg_next <= BUS_GRANTED;
        elsif (arbiter_state_reg = BUS_GRANTED) then
            if (master_bus_requests(to_integer(curr_master_counter_reg)) = '0') then
                arbiter_state_reg_next <= IDLE;
            else
                arbiter_state_reg_next <= BUS_GRANTED;
            end if;
        else
            arbiter_state_reg_next <= IDLE;
        end if;
    end process;
    
    state_outputs_proc : process(arbiter_state_reg, curr_master_counter_reg, master_bus_requests)
    begin
        curr_master_counter_en <= '0';
        slave_sel_en <= '0';
        master_sel <= (others => '1');
        slave_sel <= (others => '1');
        bus_disable <= '1';
        
        if (arbiter_state_reg = IDLE) then
            curr_master_counter_en <= not master_bus_requests(to_integer(curr_master_counter_reg));
        elsif (arbiter_state_reg = SLAVE_DECODE) then
            master_sel <= std_logic_vector(curr_master_counter_reg);
            
            bus_disable <= '0';
            slave_sel_en <= '1';
        elsif (arbiter_state_reg = BUS_GRANTED) then
            master_sel <= std_logic_vector(curr_master_counter_reg);
            slave_sel <= slave_sel_reg;
            bus_disable <= '0';
        end if;
    end process;
    
    -- ========== WRITE ARBITRATION AND DECODING ==========

end rtl;
