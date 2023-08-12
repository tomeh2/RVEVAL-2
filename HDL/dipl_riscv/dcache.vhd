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
use WORK.PKG_CPU.ALL;

entity dcache is
    port(
        bus_addr_read : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        bus_addr_write : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        bus_data_read : in std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        bus_data_write : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        bus_stbr : out std_logic;
        bus_stbw : out std_logic_vector(3 downto 0);
        bus_ackr : in std_logic;
        bus_ackw : in std_logic;
    
        read_addr_1 : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        read_tag_1 : in std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        read_valid_1 : in std_logic;
        read_ready_1 : out std_logic;
        read_data_out_1 : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        write_addr_1 : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        write_data_1 : in std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        write_cacheop_1 : in std_logic_vector(1 downto 0);
        write_size_1 : in std_logic_vector(1 downto 0);                         -- 00: 32-bit | 01: 16-bit | 10: 8-bit
        write_tag_1 : in std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        write_valid_1 : in std_logic;
        write_ready_1 : out std_logic;
        
        read_hit_1 : out std_logic;
        read_miss_1 : out std_logic;
        
        write_hit_1 : out std_logic;
        write_miss_1 : out std_logic;
        
        loaded_cacheline_tag : out std_logic_vector(DCACHE_TAG_SIZE - 1 downto 0);
        loaded_cacheline_tag_valid : out std_logic;
    
        clk : in std_logic;
        reset : in std_logic
    );
end dcache;

architecture rtl of dcache is
    

    constant ADDR_OFFSET_SIZE : integer := integer(ceil(log2(real(DCACHE_ENTRIES_PER_CACHELINE)))) + 2;
    constant ADDR_OFFSET_START : integer := integer(ceil(log2(real(DCACHE_ENTRIES_PER_CACHELINE)))) + 2;
    constant ADDR_OFFSET_END : integer := 0;

    type c1_c2_pipeline_reg_type is record
        is_write : std_logic;
    end record;
    
    type c2_c3_pipeline_reg_type is record
        is_write : std_logic;
    end record;
    
    signal c1_c2_pipeline_reg : c1_c2_pipeline_reg_type;
    signal c2_c3_pipeline_reg : c2_c3_pipeline_reg_type;
    
    signal c1_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    
    signal i_read_ready_1 : std_logic;
    signal i_write_ready_1 : std_logic;
    
    signal i_miss : std_logic;
    signal i_hit : std_logic;
    signal i_resp_valid : std_logic;
    signal i_cacheline_valid : std_logic;
    
    signal i_stall : std_logic;
begin
    c1_addr <= read_addr_1 when i_read_ready_1 else write_addr_1;    

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                c1_c2_pipeline_reg.is_write <= '0';
                c2_c3_pipeline_reg.is_write <= '0';
            else
                if (i_stall = '0') then
                    c1_c2_pipeline_reg.is_write <= i_write_ready_1;
                    c2_c3_pipeline_reg.is_write <= c1_c2_pipeline_reg.is_write;
                end if;
            end if;
        end if;
    end process;

    cache_bram_inst : entity work.cache(rtl)
                      generic map(ADDR_SIZE_BITS => CPU_ADDR_WIDTH_BITS,
                                  ENTRY_SIZE_BYTES => 4,
                                  ENTRIES_PER_CACHELINE => DCACHE_ENTRIES_PER_CACHELINE,
                                  ASSOCIATIVITY => DCACHE_ASSOCIATIVITY,
                                  NUM_SETS => DCACHE_NUM_SETS,
                                  NONCACHEABLE_BASE_ADDR => NONCACHEABLE_BASE_ADDR,
                                  
                                  ENABLE_NONCACHEABLE_ADDRS => 1,
                                  ENABLE_WRITES => 1,
                                  ENABLE_FORWARDING => 1,
                                  IS_BLOCKING => 0)
                      port map(bus_addr_read => bus_addr_read,
                               bus_addr_write => bus_addr_write,
                               bus_data_read => bus_data_read,
                               bus_data_write => bus_data_write,
                               bus_stbr => bus_stbr,
                               bus_stbw => bus_stbw,
                               bus_ackr => bus_ackr,
                               bus_ackw => bus_ackw,

                               data_read => read_data_out_1,
                               
                               addr_1 => c1_addr,
                               data_1 => write_data_1,
                               is_write_1 => i_write_ready_1,
                               cacheop_1 => write_cacheop_1,
                               write_size_1 => write_size_1,
                               valid_1 => i_read_ready_1 or i_write_ready_1, 
                               
                               clear_pipeline_reg_0 => '0',
                               clear_pipeline => '0',
                               stall => '0',
                               stall_o => i_stall,
                               
                               hit => i_hit,
                               miss => i_miss,
                               resp_valid => i_resp_valid,
                               cacheline_valid => i_cacheline_valid,
                               
                               loaded_cacheline_tag => loaded_cacheline_tag,
                               loaded_cacheline_tag_valid => loaded_cacheline_tag_valid,
                               
                               clk => clk,
                               reset => reset);
                               
    i_read_ready_1 <= read_valid_1 and not i_stall;
    i_write_ready_1 <= write_valid_1 and not read_valid_1 and not i_stall;
    
    read_ready_1 <= i_read_ready_1;
    write_ready_1 <= i_write_ready_1;
    
    read_hit_1 <= i_hit and not c2_c3_pipeline_reg.is_write and i_resp_valid;
    read_miss_1 <= i_miss and not c2_c3_pipeline_reg.is_write and i_resp_valid;
    
    write_hit_1 <= i_hit and c2_c3_pipeline_reg.is_write and i_resp_valid;
    write_miss_1 <= i_miss and c2_c3_pipeline_reg.is_write and i_resp_valid;

end rtl;
