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

-- Stall if loader active and another cache miss occurs
-- Cache set should fill up before evicting existing cachelines
-- Cache update due to write instruction and from external bus at the same time (Check what happens?)
-- Optimization: Evict non-dirty cachelines first to avoid bus accesses
-- Rework stall logic


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use WORK.PKG_CPU.ALL;

entity cache is
    generic(
        ADDR_SIZE_BITS : integer;
        ENTRY_SIZE_BYTES : integer;
        ENTRIES_PER_CACHELINE : integer;
        ASSOCIATIVITY : integer;
        NUM_SETS : integer;
        NONCACHEABLE_BASE_ADDR : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0) := (others => '0');
        DECODE_READ_DATA_IN_CACHE : boolean;
        
        ENABLE_NONCACHEABLE_ADDRS : integer;
        ENABLE_WRITES : integer;
        ENABLE_FORWARDING : integer;
        IS_BLOCKING : integer
    );

    port(
        bus_addr_read : out std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
        bus_addr_write : out std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
        bus_data_read : in std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        bus_data_write : out std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        bus_stbw : out std_logic_vector(3 downto 0);
        bus_ackw : in std_logic;
        bus_stbr : out std_logic;
        bus_ackr : in std_logic;
    
        data_read_o : out std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        cacheline_read_1 : out std_logic_vector((ADDR_SIZE_BITS - integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - integer(ceil(log2(real(NUM_SETS)))) - integer(ceil(log2(real(ENTRY_SIZE_BYTES))))
                                                 + ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8) downto 0);
                                    
        addr_1 : in std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
        data_1 : in std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        phys_dest_reg_1 : in std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0) ;
        instr_tag_1 : in std_logic_vector(INSTR_TAG_BITS - 1 downto 0) ;
        is_unsigned : in std_logic;
        cacheop_1 : in std_logic_vector(1 downto 0);
        is_write_1 : in std_logic;
        size_1 : in std_logic_vector(1 downto 0);                       -- 00: Byte | 01: Half-word | 10: Word
        valid_1 : in std_logic;
                             
        clear_pipeline_reg_0 : in std_logic;
        clear_pipeline : in std_logic;       
        stall : in std_logic;
        stall_o : out std_logic;
        
        hit : out std_logic;
        miss : out std_logic;
        resp_valid : out std_logic;
        cacheline_valid : out std_logic;
        
        loaded_cacheline_tag : out std_logic_vector(ADDR_SIZE_BITS - integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - integer(ceil(log2(real(NUM_SETS)))) - integer(ceil(log2(real(ENTRY_SIZE_BYTES)))) - 1 downto 0);
        loaded_cacheline_tag_valid : out std_logic;
                        
        clk : in std_logic;
        reset : in std_logic
    );
end cache;

architecture rtl of cache is
    constant TAG_SIZE : integer := ADDR_SIZE_BITS - integer(ceil(log2(real(ENTRIES_PER_CACHELINE)))) - integer(ceil(log2(real(NUM_SETS)))) - integer(ceil(log2(real(ENTRY_SIZE_BYTES))));
    constant INDEX_SIZE : integer := integer(ceil(log2(real(NUM_SETS))));
    constant CACHELINE_SIZE : integer := (TAG_SIZE + ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8) + 1;                      -- Total size of a cacheline in bits including control bits
    constant CACHELINE_ALIGNMENT : integer := integer(ceil(log2(real(ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES))));    -- Number of bits at the end of the address which have to be 0

    constant RADDR_TAG_START : integer := ADDR_SIZE_BITS - 1;
    constant RADDR_TAG_END : integer := ADDR_SIZE_BITS - TAG_SIZE;
    constant RADDR_INDEX_START : integer := ADDR_SIZE_BITS - TAG_SIZE - 1;
    constant RADDR_INDEX_END : integer := ADDR_SIZE_BITS - TAG_SIZE - INDEX_SIZE;
    constant RADDR_OFFSET_START : integer := ADDR_SIZE_BITS - TAG_SIZE - INDEX_SIZE - 1;
    constant RADDR_OFFSET_END : integer := ADDR_SIZE_BITS - TAG_SIZE - INDEX_SIZE - integer(ceil(log2(real(ENTRIES_PER_CACHELINE))));
    
    constant CACHELINE_DIRTY_BIT : integer := CACHELINE_SIZE - 1;
    constant CACHELINE_TAG_START : integer := CACHELINE_SIZE - 2;
    constant CACHELINE_TAG_END : integer := CACHELINE_SIZE - TAG_SIZE - 1;
    constant CACHELINE_DATA_START : integer := CACHELINE_SIZE - TAG_SIZE - 2;
    constant CACHELINE_DATA_END : integer := CACHELINE_SIZE - TAG_SIZE - ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8 - 1;
    
    type icache_block_type is array (0 to ASSOCIATIVITY - 1) of std_logic_vector(CACHELINE_SIZE - 1 downto 0);
    --type icache_type is array(0 to ICACHE_NUM_SETS - 1) of icache_block_type;
    --signal icache : icache_type;
    
    -- icache_valid_bits bits have to be outside of BRAM so that they can be reset
    signal icache_valid_bits : std_logic_vector(NUM_SETS * ASSOCIATIVITY - 1 downto 0);
    
    signal cache_set_out_bram : icache_block_type;
    signal cache_set_out : icache_block_type;
    signal cache_set_valid_1 : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal cache_set_valid_2 : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    
    signal hit_bits : std_logic_vector(ASSOCIATIVITY - 1 downto 0);          -- Only one bit can be active at a time
    signal i_stall : std_logic;
    signal i_hit : std_logic;
    signal i_write_set_select : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal i_cacheline_late_fwd_en : std_logic;
    signal i_set_full : std_logic;
    signal i_bram_read_en : std_logic;
    signal i_addr_noncacheable : std_logic;
    
    signal late_forwarding_addr_reg : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
    signal cacheline_late_forwarding_reg : std_logic_vector(CACHELINE_SIZE - 1 downto 0);   -- Needed due to BRAMs 1 cycle delay. We need to enable forwarding for one cycle even
                                                                                            -- after the cacheline is gone from C2_C3 register
    signal selected_cacheline : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal read_cacheline_bram : std_logic_vector(CACHELINE_SIZE - 1 downto 0);
    signal cacheline_update : std_logic_vector(CACHELINE_SIZE - 1 downto 0);
    signal cacheline_write : std_logic_vector(CACHELINE_SIZE - 1 downto 0);
    signal cacheline_update_en : std_logic;
    signal cacheline_evict_en : std_logic;
    signal cacheline_evict_write_en : std_logic;
    signal cacheline_addr_aligned : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
    signal cacheline_evict_addr_aligned : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
    signal cacheline_write_addr_aligned : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
    signal cacheline_load_addr_aligned : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);

    signal cbc_fwd_en : std_logic;
    signal cbc_writeback_cacheline : std_logic_vector(CACHELINE_SIZE - TAG_SIZE - 2 downto 0);
    signal cbc_writeback_addr : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
    signal cbc_writeback_write_mask : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal cbc_writeback_en : std_logic;
    signal cbc_load_busy : std_logic;
    signal cbc_write_busy : std_logic;
    signal cbc_write_done : std_logic;
    
    signal write_selected_cacheline : std_logic_vector(ASSOCIATIVITY - 1 downto 0);

    signal addr_read_cache : std_logic_vector(INDEX_SIZE - 1 downto 0);
    signal addr_write_cache : std_logic_vector(INDEX_SIZE - 1 downto 0);
    
    type c1_c2_pipeline_reg_type is record
        valid : std_logic;
        addr : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
        data : std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        cacheop_1 : std_logic_vector(1 downto 0);
        phys_dest_reg_1 : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        instr_tag_1 : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        is_write_1 : std_logic;
        is_unsigned : std_logic;
        size_1 : std_logic_vector(1 downto 0);
    end record;
    
    type c2_c3_pipeline_reg_type is record
        valid : std_logic;
        addr : std_logic_vector(ADDR_SIZE_BITS - 1 downto 0);
        data : std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
        cacheline : std_logic_vector(CACHELINE_SIZE - 1 downto 0);
        phys_dest_reg_1 : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        instr_tag_1 : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        cacheop_1 : std_logic_vector(1 downto 0);
        hit_mask : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
        evict_mask : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
        set_valid_bits : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
        set_full : std_logic;
        is_write_1 : std_logic;
        is_unsigned : std_logic;
        size_1 : std_logic_vector(1 downto 0);
        hit : std_logic;
    end record;
    
    signal c1_c2_pipeline_reg_1 : c1_c2_pipeline_reg_type;
    signal c2_c3_pipeline_reg_1 : c2_c3_pipeline_reg_type;
    
    signal load_data_decoded : std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
    signal data_read : std_logic_vector(ENTRY_SIZE_BYTES * 8 - 1 downto 0);
begin
    cache_bus_controller_inst : entity work.cache_bus_controller(rtl)
                                    generic map(ADDR_SIZE => ADDR_SIZE_BITS,
                                                ASSOCIATIVITY => ASSOCIATIVITY,
                                                ENTRY_SIZE_BYTES => ENTRY_SIZE_BYTES,
                                                ENTRIES_PER_CACHELINE => ENTRIES_PER_CACHELINE,
                                                ENABLE_NONCACHEABLE_ADDRS => ENABLE_NONCACHEABLE_ADDRS,
                                                ENABLE_WRITES => ENABLE_WRITES)
                                    port map(bus_addr_read => bus_addr_read,
                                             bus_data_read => bus_data_read,
                                             bus_addr_write => bus_addr_write,
                                             bus_data_write => bus_data_write,
                                             bus_stbw => bus_stbw,
                                             bus_ackw => bus_ackw,
                                             bus_stbr => bus_stbr,
                                             bus_ackr => bus_ackr,
                                             
                                             load_addr => cacheline_load_addr_aligned,
                                             load_location_in_set => write_selected_cacheline,
                                             load_en => c2_c3_pipeline_reg_1.valid and not c2_c3_pipeline_reg_1.hit and not i_addr_noncacheable,
                                             load_word_en => i_addr_noncacheable and c2_c3_pipeline_reg_1.valid and not c2_c3_pipeline_reg_1.is_write_1 and not c2_c3_pipeline_reg_1.hit,
                                             load_cancel => clear_pipeline,
                                             load_busy => cbc_load_busy,
                                             
                                             cache_write_word => c2_c3_pipeline_reg_1.data,
                                             cache_write_cacheline => c2_c3_pipeline_reg_1.cacheline(CACHELINE_DATA_START downto CACHELINE_DATA_END),
                                             cache_write_addr => cacheline_write_addr_aligned,
                                             cache_write_size => c2_c3_pipeline_reg_1.size_1,
                                             cache_write_en => cacheline_evict_write_en,
                                             cache_write_word_en => i_addr_noncacheable and c2_c3_pipeline_reg_1.valid and c2_c3_pipeline_reg_1.is_write_1 and not c2_c3_pipeline_reg_1.hit,
                                             write_busy => cbc_write_busy,
                                             write_done => cbc_write_done,
                                             
                                             cache_writeback_en => cbc_writeback_en,
                                             cache_writeback_addr => cbc_writeback_addr,
                                             cache_writeback_cacheline => cbc_writeback_cacheline,
                                             cache_writeback_set_addr => cbc_writeback_write_mask,
                                             
                                             fwd_en => cbc_fwd_en,
                                             
                                             clk => clk,
                                             reset => reset);
                                             
    cacheline_addr_aligned <= c2_c3_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END) & std_logic_vector(to_unsigned(0, CACHELINE_ALIGNMENT));
    cacheline_evict_addr_aligned <= c2_c3_pipeline_reg_1.cacheline(CACHELINE_TAG_START downto CACHELINE_TAG_END) & 
                                    c2_c3_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END) & 
                                    std_logic_vector(to_unsigned(0, CACHELINE_ALIGNMENT));
    
    
    noncacheable_addr_on_gen : if (ENABLE_NONCACHEABLE_ADDRS = 1) generate
        i_addr_noncacheable <= '1' when c2_c3_pipeline_reg_1.addr >= NONCACHEABLE_BASE_ADDR else '0';
        process(all)
        begin
            if (i_addr_noncacheable = '1') then
                cacheline_write_addr_aligned <= c2_c3_pipeline_reg_1.addr;

                cacheline_load_addr_aligned <= c2_c3_pipeline_reg_1.addr(ADDR_SIZE_BITS - 1 downto 2) & "00";
            else
                cacheline_write_addr_aligned <= c2_c3_pipeline_reg_1.cacheline(CACHELINE_TAG_START downto CACHELINE_TAG_END) & 
                                    c2_c3_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END) & 
                                    std_logic_vector(to_unsigned(0, CACHELINE_ALIGNMENT));
                                    
                cacheline_load_addr_aligned <= cacheline_addr_aligned;
            end if;
        end process;
    elsif (ENABLE_NONCACHEABLE_ADDRS = 0) generate
        i_addr_noncacheable <= '0';
        cacheline_write_addr_aligned <= cacheline_evict_addr_aligned;
        cacheline_load_addr_aligned <= cacheline_addr_aligned;
    end generate;

    loaded_cacheline_tag <= cbc_writeback_addr(RADDR_TAG_START downto RADDR_TAG_END);
    loaded_cacheline_tag_valid <= cbc_writeback_en;

    is_blocking_gen_on : if (IS_BLOCKING = 1) generate
        i_stall <= stall or (c2_c3_pipeline_reg_1.valid and not c2_c3_pipeline_reg_1.hit);
        stall_o <= not c2_c3_pipeline_reg_1.hit and c2_c3_pipeline_reg_1.valid;
    elsif (IS_BLOCKING = 0) generate
        process(all)
        begin
            if (ENABLE_WRITES = 1) then     -- Stall in the first phase so that we can get the updated cache block before continuing
                if (ENABLE_NONCACHEABLE_ADDRS = 1) then
                    i_stall <= (not i_hit and (cbc_load_busy or cbc_write_busy) and c1_c2_pipeline_reg_1.valid) or  -- Wont progress to c2_c3 until bus controller is clear
                               (c2_c3_pipeline_reg_1.valid and i_addr_noncacheable and not (c2_c3_pipeline_reg_1.hit));
                else
                    i_stall <= not i_hit and c1_c2_pipeline_reg_1.valid and (cbc_load_busy or cbc_write_busy);
                end if;
            else
                i_stall <= not c2_c3_pipeline_reg_1.hit and c2_c3_pipeline_reg_1.valid and cbc_load_busy;
            end if;
            stall_o <= i_stall;
        end process;
    end generate;

    cacheline_write_gen_on : if (ENABLE_WRITES = 1) generate
        cacheline_evict_write_en <= '1' when (c2_c3_pipeline_reg_1.hit = '0' and c2_c3_pipeline_reg_1.set_full = '1' and 
                                    c2_c3_pipeline_reg_1.valid = '1' and c2_c3_pipeline_reg_1.cacheline(CACHELINE_DIRTY_BIT) = '1' and  
                                    i_addr_noncacheable = '0' and c2_c3_pipeline_reg_1.cacheop_1 /= "10") or (c2_c3_pipeline_reg_1.hit = '1'  and c2_c3_pipeline_reg_1.is_write_1 = '1' and c2_c3_pipeline_reg_1.cacheop_1 = "10" and c2_c3_pipeline_reg_1.valid = '1') else '0';
        cacheline_evict_en <= '1' when (c2_c3_pipeline_reg_1.hit = '0' and 
                                        c2_c3_pipeline_reg_1.set_full = '1' and 
                                        c2_c3_pipeline_reg_1.valid = '1' and 
                                        i_addr_noncacheable = '0' and c2_c3_pipeline_reg_1.cacheop_1 /= "10") or 
                                       (c2_c3_pipeline_reg_1.hit = '1' and c2_c3_pipeline_reg_1.is_write_1 = '1' and c2_c3_pipeline_reg_1.cacheop_1 = "10" and c2_c3_pipeline_reg_1.valid = '1') else '0';
        cacheline_update_en <= '1' when cbc_writeback_en = '1' or 
                                       (c2_c3_pipeline_reg_1.is_write_1 = '1' and c2_c3_pipeline_reg_1.valid = '1' and i_addr_noncacheable = '0' and c2_c3_pipeline_reg_1.cacheop_1 /= "10") else '0';
        process(all)
        begin
            if (c2_c3_pipeline_reg_1.is_write_1 = '1' and c2_c3_pipeline_reg_1.valid = '1') then
                addr_write_cache <= c2_c3_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END);
                i_write_set_select <= c2_c3_pipeline_reg_1.hit_mask;
                cacheline_write <= cacheline_update;
            else 
                addr_write_cache <= cbc_writeback_addr(RADDR_INDEX_START downto RADDR_INDEX_END);
                i_write_set_select <= cbc_writeback_write_mask;
                cacheline_write <= '0' & cbc_writeback_addr(RADDR_TAG_START downto RADDR_TAG_END) & cbc_writeback_cacheline;
            end if;
        end process;
        
        cacheline_update_proc : process(c2_c3_pipeline_reg_1)
        begin
            cacheline_update <= c2_c3_pipeline_reg_1.cacheline;
            cacheline_update(CACHELINE_DIRTY_BIT) <= '1';
            if (c2_c3_pipeline_reg_1.size_1 = "00") then
                cacheline_update((to_integer(unsigned((c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 0)))) + 1) * 8 - 1 downto to_integer(unsigned(c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 0))) * 8)
                    <= c2_c3_pipeline_reg_1.data(7 downto 0);
            elsif (c2_c3_pipeline_reg_1.size_1 = "01") then
                cacheline_update((to_integer(unsigned((c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 1)))) + 1) * 16 - 1 downto to_integer(unsigned(c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 1))) * 16)
                    <= c2_c3_pipeline_reg_1.data(15 downto 0);
            elsif (c2_c3_pipeline_reg_1.size_1 = "10") then
                cacheline_update((to_integer(unsigned((c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 2)))) + 1) * 32 - 1 downto to_integer(unsigned(c2_c3_pipeline_reg_1.addr(CACHELINE_ALIGNMENT - 1 downto 2))) * 32)
                    <= c2_c3_pipeline_reg_1.data(31 downto 0);
            end if;
        end process;
    elsif (ENABLE_WRITES = 0) generate
        cacheline_evict_write_en <= '0';
        cacheline_evict_en <= '0';
        addr_write_cache <= cbc_writeback_addr(RADDR_INDEX_START downto RADDR_INDEX_END);
        i_write_set_select <= cbc_writeback_write_mask;
        cacheline_update <= (others => 'U');
        cacheline_update_en <= cbc_writeback_en;
        cacheline_write <= '0' & cbc_writeback_addr(RADDR_TAG_START downto RADDR_TAG_END) & cbc_writeback_cacheline;
    end generate;

    bram_gen : for i in 0 to ASSOCIATIVITY - 1 generate
        bram_inst : entity work.bram_primitive(rtl)
                    generic map(DATA_WIDTH => CACHELINE_SIZE,
                                SIZE => NUM_SETS)
                    port map(d => cacheline_write,
                             q => cache_set_out_bram(i),
                               
                             addr_read => addr_read_cache,
                             addr_write => addr_write_cache,
                                
                             read_en => i_bram_read_en,
                             write_en => i_write_set_select(i) and cacheline_update_en,
                                 
                             clk => clk,
                             reset => reset);
    end generate;
    i_bram_read_en <= valid_1 when i_stall = '0' else c1_c2_pipeline_reg_1.valid;
    addr_read_cache <= addr_1(RADDR_INDEX_START downto RADDR_INDEX_END) when i_stall = '0' else c1_c2_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END);
    
    fwd_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                i_cacheline_late_fwd_en <= '0';
                cacheline_late_forwarding_reg <= (others => '0');
                late_forwarding_addr_reg <= (others => '0');
            else
                if (i_stall = '0' and c2_c3_pipeline_reg_1.is_write_1 = '1') then
                    i_cacheline_late_fwd_en <= '1';
                    cacheline_late_forwarding_reg <= cacheline_update;
                    late_forwarding_addr_reg <= c2_c3_pipeline_reg_1.addr;
                else
                    i_cacheline_late_fwd_en <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Used to generate pseudo-random signal used to select which cacheline to evict in case of an associative cache
    ring_counter_inst : entity work.ring_counter(rtl)
                        generic map(SIZE_BITS => ASSOCIATIVITY)
                        port map(q => selected_cacheline,
                                 clk => clk,
                                 reset => reset);
    
    -- Generates a set mask which has a one at the first encountered free set entry
    process(c2_c3_pipeline_reg_1, selected_cacheline)
        variable encountered_free_cacheline : boolean;
    begin
        encountered_free_cacheline := false;
        if (c2_c3_pipeline_reg_1.set_full = '1') then
            write_selected_cacheline <= c2_c3_pipeline_reg_1.evict_mask;
        else
            write_selected_cacheline <= (others => '0');
            for i in 0 to ASSOCIATIVITY - 1 loop 
                if (c2_c3_pipeline_reg_1.set_valid_bits(i) = '0' and encountered_free_cacheline = false) then
                    write_selected_cacheline(i) <= '1';
                    encountered_free_cacheline := true;
                else
                    write_selected_cacheline(i) <= '0';
                end if;
            end loop;
        end if;
    end process;

    pipeline_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                c1_c2_pipeline_reg_1.valid <= '0';
                c1_c2_pipeline_reg_1.addr <= (others => '0');
                
                c2_c3_pipeline_reg_1.cacheline <= (others => '0');
                c2_c3_pipeline_reg_1.addr <= (others => '0');
                c2_c3_pipeline_reg_1.hit <= '0';
                c2_c3_pipeline_reg_1.valid <= '0';
                c2_c3_pipeline_reg_1.set_full <= '0';
            else
                if (clear_pipeline_reg_0 or clear_pipeline) then
                    c1_c2_pipeline_reg_1.valid <= '0';
                elsif (i_stall = '0') then
                    c1_c2_pipeline_reg_1.valid <= valid_1;
                end if;
            
                if (clear_pipeline = '1') then
                    c2_c3_pipeline_reg_1.valid <= '0';
                elsif (i_stall = '0') then
                    c2_c3_pipeline_reg_1.valid <= c1_c2_pipeline_reg_1.valid and not clear_pipeline_reg_0;
                end if;
                
                if (i_stall = '0') then
                    c1_c2_pipeline_reg_1.addr <= addr_1;
                    c1_c2_pipeline_reg_1.is_write_1 <= is_write_1;
                    c1_c2_pipeline_reg_1.cacheop_1 <= cacheop_1;
                    c1_c2_pipeline_reg_1.is_unsigned <= is_unsigned;
                    c1_c2_pipeline_reg_1.phys_dest_reg_1 <= phys_dest_reg_1;
                    c1_c2_pipeline_reg_1.instr_tag_1 <= instr_tag_1;
                    c1_c2_pipeline_reg_1.is_unsigned <= is_unsigned;
                    c1_c2_pipeline_reg_1.size_1 <= size_1;
                    c1_c2_pipeline_reg_1.data <= data_1;
                    
                    if (ENABLE_WRITES = 1) then     -- FORWARD UPDATED CACHELINE IN CASE OF ACCESS TO THE SAME ONE IN THE PREVIOUS STAGE
                        if (c2_c3_pipeline_reg_1.is_write_1 = '1' and c2_c3_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END) = c1_c2_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END)) then
                            c2_c3_pipeline_reg_1.cacheline <= cacheline_update;
                        elsif (i_cacheline_late_fwd_en = '1' and late_forwarding_addr_reg(RADDR_TAG_START downto RADDR_INDEX_END) = c1_c2_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END)) then
                            c2_c3_pipeline_reg_1.cacheline <= cacheline_late_forwarding_reg;
                        else
                            c2_c3_pipeline_reg_1.cacheline <= read_cacheline_bram;
                        end if;
                    else
                        c2_c3_pipeline_reg_1.cacheline <= read_cacheline_bram;
                    end if;

                    c2_c3_pipeline_reg_1.evict_mask <= selected_cacheline;
                    c2_c3_pipeline_reg_1.set_valid_bits <= cache_set_valid_2;
                    c2_c3_pipeline_reg_1.addr <= c1_c2_pipeline_reg_1.addr;
                    c2_c3_pipeline_reg_1.hit <= i_hit;
                    c2_c3_pipeline_reg_1.hit_mask <= hit_bits;
                    c2_c3_pipeline_reg_1.is_write_1 <= c1_c2_pipeline_reg_1.is_write_1;
                    c2_c3_pipeline_reg_1.phys_dest_reg_1 <= c1_c2_pipeline_reg_1.phys_dest_reg_1;
                    c2_c3_pipeline_reg_1.instr_tag_1 <= c1_c2_pipeline_reg_1.instr_tag_1;
                    c2_c3_pipeline_reg_1.is_unsigned <= c1_c2_pipeline_reg_1.is_unsigned;
                    c2_c3_pipeline_reg_1.cacheop_1 <= c1_c2_pipeline_reg_1.cacheop_1;
                    c2_c3_pipeline_reg_1.size_1 <= c1_c2_pipeline_reg_1.size_1;
                    c2_c3_pipeline_reg_1.data <= c1_c2_pipeline_reg_1.data;
                    c2_c3_pipeline_reg_1.set_full <= i_set_full;
                else
                    if (ENABLE_FORWARDING = 1) then
                        if (cbc_fwd_en = '1' and c2_c3_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END) = cbc_writeback_addr(RADDR_TAG_START downto RADDR_INDEX_END)) then
                            c2_c3_pipeline_reg_1.hit <= '1';
                            c2_c3_pipeline_reg_1.cacheline <= cacheline_write;
                        end if;
                        
                        if (cbc_write_done = '1' and i_addr_noncacheable = '1' and c2_c3_pipeline_reg_1.valid = '1') then
                            c2_c3_pipeline_reg_1.hit <= '1';
                        end if;
                    end if;
                end if; 
            end if;
        end if;
    end process;

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                icache_valid_bits <= (others => '0');
            else
                if (i_stall = '0') then
                    for i in 0 to ASSOCIATIVITY - 1 loop
                        cache_set_valid_1(i) <= icache_valid_bits(to_integer(unsigned(addr_1(RADDR_INDEX_START downto RADDR_INDEX_END))) * ASSOCIATIVITY + i);
                    end loop;
                else
                    for i in 0 to ASSOCIATIVITY - 1 loop
                        cache_set_valid_1(i) <= icache_valid_bits(to_integer(unsigned(c1_c2_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END))) * ASSOCIATIVITY + i);
                    end loop;
                end if;
                
                if (ENABLE_WRITES = 1) then
                    if (cacheline_evict_en = '1') then 
                        for i in 0 to ASSOCIATIVITY - 1 loop
                            if (c2_c3_pipeline_reg_1.evict_mask(i) = '1') then
                                icache_valid_bits(to_integer(unsigned(c2_c3_pipeline_reg_1.addr(RADDR_INDEX_START downto RADDR_INDEX_END))) * ASSOCIATIVITY + i) <= '0';
                            end if;
                        end loop;
                    end if;
                end if;
                
                if (cacheline_update_en = '1') then
                    for i in 0 to ASSOCIATIVITY - 1 loop
                        if (cbc_writeback_write_mask(i) = '1') then
                            icache_valid_bits(to_integer(unsigned(cbc_writeback_addr(RADDR_INDEX_START downto RADDR_INDEX_END))) * ASSOCIATIVITY + i) <= '1';
                            cache_set_valid_1(i) <= '1';
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
    set_valid_gen_wren : if (ENABLE_WRITES = 1) generate
        process(all)
        begin
            if (c2_c3_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END) = c1_c2_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_INDEX_END) and 
                c2_c3_pipeline_reg_1.valid = '1' and 
                c1_c2_pipeline_reg_1.valid = '1' and
                cacheline_evict_en = '1') then
                cache_set_valid_2 <= cache_set_valid_1 and not write_selected_cacheline;
            else
                cache_set_valid_2 <= cache_set_valid_1;
            end if;
        end process;
    elsif (ENABLE_WRITES = 0) generate
        cache_set_valid_2 <= cache_set_valid_1;
    end generate;
    
    cache_set_out <= cache_set_out_bram;

    set_full_proc : process(all)
        variable v_full : std_logic;
    begin
        v_full := '1';
        for i in 0 to ASSOCIATIVITY - 1 loop
            v_full := v_full and cache_set_valid_2(i);
        end loop;
        i_set_full <= v_full;
    end process;

    hit_detector_proc : process(all)
    begin
        for i in 0 to ASSOCIATIVITY - 1 loop
            hit_bits(i) <= '1' when (c1_c2_pipeline_reg_1.valid = '1' and (cache_set_valid_2(i) = '1') and 
                                     c1_c2_pipeline_reg_1.addr(RADDR_TAG_START downto RADDR_TAG_END) = cache_set_out(i)(CACHELINE_TAG_START downto CACHELINE_TAG_END)) 
                                     else '0';
        end loop;
    end process;
    
    process(all)
        variable temp : std_logic;
    begin
        temp := '0';
        for i in 0 to ASSOCIATIVITY - 1 loop
            temp := temp or hit_bits(i);
        end loop;
        i_hit <= temp;
    end process;
    
    cacheline_hit_gen_wrnen : if (ENABLE_WRITES = 0) generate
        cacheline_with_hit_gen : process(all)
        begin
            read_cacheline_bram <= (others => '0');
            for i in 0 to ASSOCIATIVITY - 1 loop
                if (hit_bits(i) = '1') then
                    read_cacheline_bram <= cache_set_out(i);
                end if;
            end loop; 
        end process;
    elsif (ENABLE_WRITES = 1) generate
        cacheline_with_hit_gen : process(all)
        begin
            read_cacheline_bram <= (others => '0');
            for i in 0 to ASSOCIATIVITY - 1 loop
                if (i_set_full = '1' and i_hit = '0') then
                    if (selected_cacheline(i) = '1') then
                        read_cacheline_bram <= cache_set_out(i);
                    end if;
                else
                    if (hit_bits(i) = '1') then
                        read_cacheline_bram <= cache_set_out(i);
                    end if;
                end if;
            end loop; 
        end process;
    end generate;
    
    data_out_gen : process(all)
    begin
        cacheline_read_1 <= c2_c3_pipeline_reg_1.cacheline;
        data_read <= (others => '0');
        for j in 0 to ENTRIES_PER_CACHELINE - 1 loop
            if (to_integer(unsigned(c2_c3_pipeline_reg_1.addr(RADDR_OFFSET_START downto RADDR_OFFSET_END))) = j) then
                data_read <= c2_c3_pipeline_reg_1.cacheline(CACHELINE_DATA_END + ENTRY_SIZE_BYTES * 8 * (j + 1) - 1 downto CACHELINE_DATA_END + ENTRY_SIZE_BYTES * 8 * (j));
            end if;
        end loop;
    end process;
    
    dec_data_cache_gen : if (DECODE_READ_DATA_IN_CACHE = true) generate
        process(all)
        begin
            load_data_decoded(31 downto 0) <= (others => '0');     
            if (c2_c3_pipeline_reg_1.size_1 = "00") then                  -- LB
                if (c2_c3_pipeline_reg_1.addr(1 downto 0) = "00") then
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 8) <= (others => data_read(7));   
                    end if;
                    load_data_decoded(7 downto 0) <= data_read(7 downto 0);
                elsif (c2_c3_pipeline_reg_1.addr(1 downto 0) = "01") then
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 8) <= (others => data_read(15));   
                    end if;
                    load_data_decoded(7 downto 0) <= data_read(15 downto 8);
                elsif (c2_c3_pipeline_reg_1.addr(1 downto 0) = "10") then
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 8) <= (others => data_read(23));   
                    end if;
                    load_data_decoded(7 downto 0) <= data_read(23 downto 16);
                elsif (c2_c3_pipeline_reg_1.addr(1 downto 0) = "11") then
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 8) <= (others => data_read(31));   
                    end if;
                    load_data_decoded(7 downto 0) <= data_read(31 downto 24);
                end if;
            elsif (c2_c3_pipeline_reg_1.size_1 = "01") then
                if (c2_c3_pipeline_reg_1.addr(0) = '0') then
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 16) <= (others => data_read(15));   
                    end if;
                    load_data_decoded(15 downto 0) <= data_read(15 downto 0);
                else
                    if (c2_c3_pipeline_reg_1.is_unsigned = '0') then
                        load_data_decoded(31 downto 16) <= (others => data_read(31));   
                    end if;
                    load_data_decoded(15 downto 0) <= data_read(31 downto 16);
                end if;
            elsif (c2_c3_pipeline_reg_1.size_1 = "10") then  
                    load_data_decoded <= data_read;
            else
                load_data_decoded(31 downto 0) <= (others => '0');
            end if;
        end process;   
        data_read_o <= load_data_decoded;
    else generate
        data_read_o <= data_read;
    end generate;
    
    hit <= c2_c3_pipeline_reg_1.hit and c2_c3_pipeline_reg_1.valid;
    miss <= not c2_c3_pipeline_reg_1.hit and c2_c3_pipeline_reg_1.valid;
    cacheline_valid <= c2_c3_pipeline_reg_1.valid and c2_c3_pipeline_reg_1.hit;
    resp_valid <= c2_c3_pipeline_reg_1.valid and not i_stall;
end rtl;















