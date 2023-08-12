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

entity icache is
    port(
        read_addr : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        read_en : in std_logic;
        read_cancel : in std_logic;
        read_cancel_1 : in std_logic;
        stall : in std_logic;
        
        fetching : out std_logic;
        hit : out std_logic;
        miss : out std_logic; 
        data_valid : out std_logic;
        data_out : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
        bus_addr_read : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        bus_data_read : in std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        bus_stbr : out std_logic;
        bus_ackr : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end icache;

architecture rtl of icache is
    -- ==================== BUS SIGNALS ====================
    signal i_miss : std_logic;
    signal i_stall : std_logic;
begin
    -- ==================== CACHE LOGIC ====================
    cache_bram_inst : entity work.cache(rtl)
                      generic map(ADDR_SIZE_BITS => CPU_ADDR_WIDTH_BITS,
                                  ENTRY_SIZE_BYTES => 4,
                                  ENTRIES_PER_CACHELINE => ICACHE_INSTR_PER_CACHELINE,
                                  ASSOCIATIVITY => ICACHE_ASSOCIATIVITY,
                                  NUM_SETS => ICACHE_NUM_SETS,
                                  
                                  ENABLE_NONCACHEABLE_ADDRS => 0,
                                  ENABLE_WRITES => 0,
                                  ENABLE_FORWARDING => 1,
                                  IS_BLOCKING => 1)
                      port map(bus_data_read => bus_data_read,
                               bus_addr_read => bus_addr_read,
                               bus_stbr => bus_stbr,
                               bus_ackr => bus_ackr,
                               bus_ackw => '0',
                      
                               data_read => data_out,
                               
                               addr_1 => read_addr,
                               data_1 => (others => '0'),
                               is_write_1 => '0',
                               cacheop_1 => "00",
                               write_size_1 => (others => '0'),
                               valid_1 => read_en,
                               
                               clear_pipeline_reg_0 => read_cancel_1,
                               clear_pipeline => read_cancel,
                               stall => stall,
                               stall_o => i_stall,
                               
                               hit => hit,
                               miss => i_miss,
                               cacheline_valid => data_valid,
                               
                               clk => clk,
                               reset => reset);
                               
    miss <= i_miss;
    fetching <= i_stall;
end rtl;





















