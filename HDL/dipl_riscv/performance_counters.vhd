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
use WORK.PKG_CPU.ALL;

entity performance_counters is
    port(
        -- BUS
        bus_addr_read : in std_logic_vector(3 downto 0);
        bus_data_read : out std_logic_vector(31 downto 0);
        bus_stbr : in std_logic;
        bus_ackr : out std_logic;
    
        -- FE
        perf_targ_mispred : in std_logic;
        perf_icache_miss : in std_logic;
        perf_bc_empty : in std_logic;
        perf_fifo_full : in std_logic;
        
        -- EE
        perf_cdb_mispred : in std_logic;
        perf_commit_ready : in std_logic;
        perf_sched_full : in std_logic;
        perf_lq_full : in std_logic;
        perf_sq_full : in std_logic;
        perf_reg_alloc_empty : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end performance_counters;

architecture rtl of performance_counters is
    signal targ_mispred_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal icache_miss_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal bc_empty_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal fifo_full_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal cdb_mispred_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal commit_ready_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal sched_full_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal lq_full_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal sq_full_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    signal reg_alloc_empty_counter : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    
    signal timer_temp : unsigned(PERF_COUNTERS_WIDTH_BITS - 1 downto 0);
    
    signal bus_ackr_i : std_logic;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                targ_mispred_counter <= (others => '0');
                icache_miss_counter <= (others => '0');
                bc_empty_counter <= (others => '0');
                fifo_full_counter <= (others => '0');
                cdb_mispred_counter <= (others => '0');
                commit_ready_counter <= (others => '0');
                sched_full_counter <= (others => '0');
                lq_full_counter <= (others => '0');
                sq_full_counter <= (others => '0');
                reg_alloc_empty_counter <= (others => '0');
                
                timer_temp <= (others => '0');
            else
                if (perf_targ_mispred = '1') then
                    targ_mispred_counter <= targ_mispred_counter + 1;
                end if;
                
                if (perf_icache_miss = '1') then
                    icache_miss_counter <= icache_miss_counter + 1;
                end if;
                
                if (perf_bc_empty = '1') then
                    bc_empty_counter <= bc_empty_counter + 1;
                end if;
                
                if (perf_fifo_full = '1') then
                    fifo_full_counter <= fifo_full_counter + 1;
                end if;
                
                if (perf_cdb_mispred = '1') then
                    cdb_mispred_counter <= cdb_mispred_counter + 1;
                end if;
                
                if (perf_commit_ready = '1') then
                    commit_ready_counter <= commit_ready_counter + 1;
                end if;
                
                if (perf_sched_full = '1') then
                    sched_full_counter <= sched_full_counter + 1;
                end if;
                
                if (perf_lq_full = '1') then
                    lq_full_counter <= lq_full_counter + 1;
                end if;
                
                if (perf_sq_full = '1') then
                    sq_full_counter <= sq_full_counter + 1;
                end if;
                
                if (perf_reg_alloc_empty = '1') then
                    reg_alloc_empty_counter <= reg_alloc_empty_counter + 1;
                end if;
                
                timer_temp <= timer_temp + 1;
            end if;
        end if;
    end process;
    
    addr_decode : process(all)
    begin
        case bus_addr_read is
            when "0000" => 
                bus_data_read <= std_logic_vector(targ_mispred_counter);
            when "0001" => 
                bus_data_read <= std_logic_vector(icache_miss_counter);
            when "0010" => 
                bus_data_read <= std_logic_vector(bc_empty_counter);
            when "0011" => 
                bus_data_read <= std_logic_vector(fifo_full_counter);
            when "0100" => 
                bus_data_read <= std_logic_vector(commit_ready_counter);
            when "0101" => 
                bus_data_read <= std_logic_vector(sched_full_counter);
            when "0110" => 
                bus_data_read <= std_logic_vector(lq_full_counter);
            when "0111" => 
                bus_data_read <= std_logic_vector(sq_full_counter);
            when "1000" => 
                bus_data_read <= std_logic_vector(reg_alloc_empty_counter);
            when "1001" => 
                bus_data_read <= std_logic_vector(cdb_mispred_counter);
            when "1010" => 
                bus_data_read <= std_logic_vector(timer_temp);
            when others => 
                bus_data_read <= (others => '0');
        end case;
    end process;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                bus_ackr_i <= '0';
            else
                bus_ackr_i <= bus_stbr and not bus_ackr_i; 
            end if;
        end if;
    end process;
    
    bus_ackr <= bus_ackr_i;


end rtl;
