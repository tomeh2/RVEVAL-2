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
use IEEE.MATH_REAL.ALL;
use WORK.PKG_CPU.ALL;

entity cache_2 is
    generic(
        DATA_WIDTH : integer := 32;
        ADDRESS_WIDTH : integer := 32;
        
        ENTRY_SIZE_BYTES : integer;
        ENTRIES_PER_CACHELINE : integer;
        NUM_SETS : integer;
        ASSOCIATIVITY : integer := 1;
        IS_BLOCKING : boolean
    );
    port(
        read_input_port : in cache_read_uop_type;
        write_input_port : in cache_write_uop_type;
        
        clk : in std_logic;
        reset : in std_logic
    );
end cache_2;

architecture rtl of cache_2 is
    constant TAG_SIZE : integer := ADDRESS_WIDTH - f_bits_needed(ENTRIES_PER_CACHELINE) - f_bits_needed(NUM_SETS) - f_bits_needed(ENTRY_SIZE_BYTES);
    constant INDEX_SIZE : integer := f_bits_needed(NUM_SETS);
    constant CACHELINE_SIZE : integer := (TAG_SIZE + ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8) + 1;                      -- Total size of a cacheline in bits including control bits
    constant CACHELINE_ALIGNMENT : integer := f_bits_needed(ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES);    -- Number of bits at the end of the address which have to be 0
    
    constant CACHELINE_TAG_START : integer := CACHELINE_SIZE - 1;
    constant CACHELINE_TAG_END : integer := CACHELINE_SIZE - TAG_SIZE;
    constant CACHELINE_DATA_START : integer := CACHELINE_SIZE - TAG_SIZE - 1;
    constant CACHELINE_DATA_END : integer := CACHELINE_SIZE - TAG_SIZE - ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8;
    constant CACHELINE_DIRTY_BIT : integer := CACHELINE_SIZE - TAG_SIZE - ENTRIES_PER_CACHELINE * ENTRY_SIZE_BYTES * 8 - 1;
    
    constant ADDR_INDEX_START : integer := ADDRESS_WIDTH - TAG_SIZE - 1;
    constant ADDR_INDEX_END : integer := ADDRESS_WIDTH - TAG_SIZE - INDEX_SIZE;

    type cache_block_valid_bits_type is array (0 to NUM_SETS - 1) of std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal cache_valid_bits : cache_block_valid_bits_type;

    type cache_block_type is record
        tag : std_logic_vector(TAG_SIZE - 1 downto 0);
        data : std_logic_vector(ENTRY_SIZE_BYTES * 8 * ENTRIES_PER_CACHELINE - 1 downto 0);
        dirty : std_logic;
    end record;

    type bram_read_cache_block_type is array (ASSOCIATIVITY - 1 downto 0) of cache_block_type;
    signal bram_read_cache_block : bram_read_cache_block_type;
    signal bram_read_cache_block_valid_bits : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    type bram_write_cache_block_type is array (ASSOCIATIVITY - 1 downto 0) of cache_block_type;
    signal bram_write_cache_block : bram_write_cache_block_type;
    signal bram_write_cache_block_valid_bits : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
   
    signal hit_mask_read : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    signal hit_mask_write : std_logic_vector(ASSOCIATIVITY - 1 downto 0);
    
    signal cacheline_read_with_hit : cache_block_type;
    signal cacheline_write_with_hit : cache_block_type;
    
    signal cacheline_write : cache_block_type;
   
    type pipeline_reg_0_type is record
        read_1 : cache_read_uop_type;
        write_1 : cache_write_uop_type;
    end record;
    signal pipeline_reg_0 : pipeline_reg_0_type;
    signal pipeline_reg_0_en : std_logic;
    
    type pipeline_reg_1_type is record
        read_1 : cache_read_uop_type;
        write_1 : cache_write_uop_type;
    
        bram_read_cache_block : bram_read_cache_block_type;
        bram_write_cache_block : bram_write_cache_block_type;
    end record;
    signal pipeline_reg_1 : pipeline_reg_1_type;
    signal pipeline_reg_1_en : std_logic;
    
    type pipeline_reg_2_type is record
        read_1 : cache_read_uop_type;
        write_1 : cache_write_uop_type;
    
        read_cache_block : cache_block_type;
        write_cache_block : cache_block_type;
    end record;
    signal pipeline_reg_2 : pipeline_reg_2_type;
    signal pipeline_reg_2_en : std_logic;
begin
    cacheline_valid_bits_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                cache_valid_bits <= (others => (others => '1'));
            else
            
            end if;
        end if;
    end process;

    pipeline_reg_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_0.write_1.valid <= '0';
                pipeline_reg_1.write_1.valid <= '0';
                pipeline_reg_2.write_1.valid <= '0';
                
                pipeline_reg_0.read_1.valid <= '0';
                pipeline_reg_1.read_1.valid <= '0';
                pipeline_reg_2.read_1.valid <= '0';
            else
                if (pipeline_reg_0_en = '1') then
                    pipeline_reg_0.read_1 <= read_input_port;
                    pipeline_reg_0.write_1 <= write_input_port;
                else
                    if (pipeline_reg_1_en = '1' and pipeline_reg_0.read_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_0.read_1.valid <= '0';                                        -- to the next register even if enable is 0
                    end if;
                    
                    if (pipeline_reg_1_en = '1' and pipeline_reg_0.write_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_0.write_1.valid <= '0';                                        -- to the next register even if enable is 0
                    end if;
                end if;
                
                if (pipeline_reg_1_en = '1') then
                    pipeline_reg_1.bram_read_cache_block <= bram_read_cache_block;
                    pipeline_reg_1.bram_write_cache_block <= bram_write_cache_block;
                    
                    pipeline_reg_1.read_1 <= pipeline_reg_0.read_1;
                    pipeline_reg_1.write_1 <= pipeline_reg_0.write_1;
                else
                    if (pipeline_reg_2_en = '1' and pipeline_reg_1.read_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_1.read_1.valid <= '0';            -- to the next register even if enable is 0
                    end if;
                    
                    if (pipeline_reg_2_en = '1' and pipeline_reg_1.write_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_1.write_1.valid <= '0';            -- to the next register even if enable is 0
                    end if;
                end if;
                
                if (pipeline_reg_2_en = '1') then
                    pipeline_reg_2.read_1 <= pipeline_reg_1.read_1;
                    pipeline_reg_2.write_1 <= pipeline_reg_1.write_1;
                    
                    pipeline_reg_2.read_cache_block <= cacheline_read_with_hit;
                    pipeline_reg_2.write_cache_block <= cacheline_write_with_hit;
                else
                    if (pipeline_reg_2.read_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_2.read_1.valid <= '0';            -- to the next register even if enable is 0
                    end if;
                    
                    if (pipeline_reg_2.write_1.valid = '1') then        -- Make sure to clear the valid bit if the uOP that was in this pipeline reg moved
                        pipeline_reg_2.write_1.valid <= '0';            -- to the next register even if enable is 0
                    end if;
                end if;
            end if;
        end if;
    end process;
    pipeline_reg_0_en <= '1';
    pipeline_reg_1_en <= '1';
    pipeline_reg_2_en <= '1';

    -- ===================================================================================
    -- /////////////////////////////////// PIPELINE 0 ////////////////////////////////////
    -- ===================================================================================
    bram_gen : for i in 0 to ASSOCIATIVITY - 1 generate
        bram_inst : entity work.bram_primitive(rtl)
                    generic map(DATA_WIDTH => CACHELINE_SIZE,
                                SIZE => NUM_SETS)
                    port map(d => cacheline_write.tag & cacheline_write.data & cacheline_write.dirty,
                             q1(CACHELINE_TAG_START downto CACHELINE_TAG_END) => bram_read_cache_block(i).tag,            -- Cache block read by the read uOP
                             q1(CACHELINE_DATA_START downto CACHELINE_DATA_END) => bram_read_cache_block(i).data,            -- Cache block read by the read uOP
                             q1(CACHELINE_DIRTY_BIT) => bram_read_cache_block(i).dirty,            -- Cache block read by the read uOP
                               
                             addr_read_1 => read_input_port.address(ADDR_INDEX_START downto ADDR_INDEX_END),
                             addr_read_2 => write_input_port.address(ADDR_INDEX_START downto ADDR_INDEX_END),
                             addr_write => pipeline_reg_2.write_1.address(ADDR_INDEX_START downto ADDR_INDEX_END),
                                
                             read_en => read_input_port.valid and not (pipeline_reg_0.read_1.valid and not pipeline_reg_1_en),
                             write_en => pipeline_reg_2.write_1.valid,
                                 
                             clk => clk,
                             reset => reset);
    end generate;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                bram_read_cache_block_valid_bits <= (others => '0');
                bram_write_cache_block_valid_bits <= (others => '0');
            else
                if (read_input_port.valid = '1') then
                    bram_read_cache_block_valid_bits <= cache_valid_bits(to_integer(unsigned(read_input_port.address(ADDR_INDEX_START downto ADDR_INDEX_END))));
                end if;
                
                if (write_input_port.valid = '1') then
                    bram_write_cache_block_valid_bits <= cache_valid_bits(to_integer(unsigned(write_input_port.address(ADDR_INDEX_START downto ADDR_INDEX_END))));
                end if;
            end if;
        end if;
    end process;

    -- ===================================================================================
    -- /////////////////////////////////// PIPELINE 1 ////////////////////////////////////
    -- ===================================================================================
    gen_hit_mask : process(bram_read_cache_block_valid_bits, bram_read_cache_block, pipeline_reg_0, pipeline_reg_0.read_1)
    begin
        for i in 0 to ASSOCIATIVITY - 1 loop
            hit_mask_read(i) <= '1' when bram_read_cache_block_valid_bits(i) = '1' and bram_read_cache_block(i).tag = pipeline_reg_0.read_1.address else '0';
            hit_mask_write(i) <= '1' when bram_write_cache_block_valid_bits(i) = '1' and bram_write_cache_block(i).tag = pipeline_reg_0.write_1.address else '0';
        end loop;
    end process;
    
    select_cacheline_with_hit : process(all)
    begin
        for i in 0 to ASSOCIATIVITY - 1 loop
            if (hit_mask_read(i) = '1') then
                cacheline_read_with_hit <= bram_read_cache_block(i);
            end if;
            
            if (hit_mask_write(i) = '1') then
                cacheline_write_with_hit <= bram_write_cache_block(i);
            end if;
        end loop;
    end process;

    -- ===================================================================================
    -- /////////////////////////////////// PIPELINE 2 ////////////////////////////////////
    -- ===================================================================================
    cacheline_modify : process(pipeline_reg_2, pipeline_reg_2.write_1)
    begin
        cacheline_write <= pipeline_reg_2.write_cache_block;
        cacheline_write.dirty <= '1';
        if (pipeline_reg_2.write_1.size = "00") then
            cacheline_write.data((to_integer(unsigned((pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 0)))) + 1) * 8 - 1 downto to_integer(unsigned(pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 0))) * 8) 
                <= pipeline_reg_2.write_1.data(7 downto 0);
        elsif (pipeline_reg_2.write_1.size = "01") then
            cacheline_write.data((to_integer(unsigned((pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 1)))) + 1) * 16 - 1 downto to_integer(unsigned(pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 1))) * 16) 
                <= pipeline_reg_2.write_1.data(15 downto 0);
        elsif (pipeline_reg_2.write_1.size = "10") then
            cacheline_write.data((to_integer(unsigned((pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 2)))) + 1) * 32 - 1 downto to_integer(unsigned(pipeline_reg_2.write_1.address(CACHELINE_ALIGNMENT - 1 downto 2))) * 32) 
                <= pipeline_reg_2.write_1.data(31 downto 0);
        end if;
    end process;
    
    
end rtl;
















