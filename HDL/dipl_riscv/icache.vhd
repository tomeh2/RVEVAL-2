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
    constant TAG_SIZE : integer := CPU_ADDR_WIDTH_BITS - integer(ceil(log2(real(ICACHE_INSTR_PER_CACHELINE)))) - integer(ceil(log2(real(ICACHE_NUM_SETS)))) - 2;
    constant CACHELINE_SIZE : integer := (TAG_SIZE + ICACHE_INSTR_PER_CACHELINE * 32);                      -- Total size of a cacheline in bits including control bits
    constant CACHELINE_ALIGNMENT : integer := integer(ceil(log2(real(ICACHE_INSTR_PER_CACHELINE * 4))));    -- Number of bits at the end of the address which have to be 0
    constant RADDR_OFFSET_START : integer := integer(ceil(log2(real(ICACHE_INSTR_PER_CACHELINE))));
    constant RADDR_OFFSET_END : integer := 2;

    signal icache_miss_cacheline_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal icache_miss_cacheline_addr_reg : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal icache_miss : std_logic;
    
    signal fetch_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    
    signal cacheline_update_en : std_logic;
    -- ==================== BUS SIGNALS ====================
    signal i_bus_addr_read : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    signal i_miss : std_logic;
    signal i_stall : std_logic;
    
    type bus_read_state_type is (IDLE,
                                BUSY,
                                CACHE_WRITE);
    signal bus_read_state : bus_read_state_type;
    signal bus_read_state_next : bus_read_state_type;
    
    signal loader_busy : std_logic;
    signal i_data_out : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal fetched_cacheline_data : std_logic_vector(ICACHE_INSTR_PER_CACHELINE * 32 - 1 downto 0); 
    signal fetched_cacheline : std_logic_vector(CACHELINE_SIZE - 1 downto 0);
    signal fetched_instrs_counter : unsigned(integer(ceil(log2(real(ICACHE_INSTR_PER_CACHELINE)))) - 1 downto 0);
    -- =====================================================
begin
    -- ==================== BUS SIDE LOGIC ====================
--    bus_addr_read_cntrl : process(clk)
--    begin
--        if (rising_edge(clk)) then
--            if (reset = '1') then
--                i_bus_addr_read <= (others => '0');
--                icache_miss_cacheline_addr_reg <= (others => '0');
--            else
--                if (bus_read_state = IDLE and icache_miss = '1') then
--                    i_bus_addr_read <= icache_miss_cacheline_addr;--(CPU_ADDR_WIDTH_BITS - 1 downto CACHELINE_ALIGNMENT) & std_logic_vector(to_unsigned(0, CACHELINE_ALIGNMENT));
--                    icache_miss_cacheline_addr_reg <= icache_miss_cacheline_addr;
--                elsif (bus_ackr = '1') then
--                    i_bus_addr_read <= std_logic_vector(unsigned(i_bus_addr_read) + 4);
--                end if;
--            end if;
--        end if;
--    end process;
    
--    bus_read_sm_state_reg_cntrl : process(clk)
--    begin
--        if (rising_edge(clk)) then
--            if (reset = '1') then
--                bus_read_state <= IDLE;
--            else
--                bus_read_state <= bus_read_state_next;
--            end if;
--        end if;
--    end process;
    
--    bus_read_sm_next_state : process(all)
--    begin
--        if (bus_read_state = IDLE) then
--            if (icache_miss = '1' and read_cancel = '0' and read_en = '1') then
--                bus_read_state_next <= BUSY;
--            else
--                bus_read_state_next <= IDLE;
--            end if;
--        elsif (bus_read_state = BUSY) then
--            if (read_cancel = '1') then
--                bus_read_state_next <= IDLE;
--            elsif (fetched_instrs_counter = ICACHE_INSTR_PER_CACHELINE - 1 and bus_ackr = '1') then
--                bus_read_state_next <= CACHE_WRITE;
--            else
--                bus_read_state_next <= BUSY;
--            end if;
--        elsif (bus_read_state = CACHE_WRITE) then
--            bus_read_state_next <= IDLE;
--        end if;
--    end process;
    
--    bus_read_sm_actions : process(all)
--    begin
--        cacheline_update_en <= '0';
--        bus_stbr <= '0';
--        loader_busy <= '1';

--        if (bus_read_state = IDLE) then
--           loader_busy <= '0';
--        elsif (bus_read_state = BUSY) then
--            bus_stbr <= '1';
--        elsif (bus_read_state = CACHE_WRITE) then
--            cacheline_update_en <= not read_cancel;
--        end if;
--    end process;
    
--    fetched_cacheline_cntrl : process(clk)
--    begin
--        if (rising_edge(clk)) then
--            if (bus_read_state = BUSY and bus_ackr = '1') then
--                fetched_cacheline_data(32 * (to_integer(fetched_instrs_counter) + 1) - 1 downto 32 * to_integer(fetched_instrs_counter)) <= bus_data_read;
--            end if;
--        end if;
--    end process;
    
--    fetched_instrs_counter_cntrl : process(clk)
--    begin
--        if (rising_edge(clk)) then
--            if (bus_read_state = IDLE) then
--                fetched_instrs_counter <= (others => '0');
--            elsif (bus_read_state = BUSY and bus_ackr = '1') then
--                fetched_instrs_counter <= fetched_instrs_counter + 1;
--            end if;
--        end if;
--    end process;
    
--    bus_addr_read <= i_bus_addr_read;
    
--    miss <= icache_miss;
--    fetching <= '1' when bus_read_state /= IDLE or bus_read_state_next /= IDLE else '0';
    -- ========================================================
    
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
                               write_size_1 => (others => '0'),
                               valid_1 => read_en,
                               
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





















