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
use WORK.PKG_FU.ALL;
use WORK.PKG_AXI.ALL;

-- Note: Addresses are tagged with QUEUE entry numbers. Data entries in the store queue are tagged with the physical register tag.
-- Ready bit in LQ might be unnecessary
-- Potential problem: What if another data comes in before the current one has been written into the register file?

entity load_store_unit_cache is
    generic(
        SQ_ENTRIES : integer;
        LQ_ENTRIES : integer  
    );
    port(
        cdb_in : in cdb_type;
        cdb_out : out cdb_type;
        cdb_request : out std_logic;
        cdb_granted : in std_logic;

        next_uop : in uop_full_type; 
        next_uop_valid : in std_logic;
        -- Instruction tags
        instr_tag : in std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
    
        -- Address generation results bus
        generated_address : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        sq_calc_addr_tag : in std_logic_vector(integer(ceil(log2(real(SQ_ENTRIES)))) - 1 downto 0);
        sq_calc_addr_valid : in std_logic;
        lq_calc_addr_tag : in std_logic_vector(integer(ceil(log2(real(LQ_ENTRIES)))) - 1 downto 0); 
        lq_calc_addr_valid : in std_logic;
        
        -- Store data fetch results bus
        sq_store_data : in std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        sq_store_data_tag : in std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        sq_store_data_valid : in std_logic;
        
        -- Tag of the next entry that will be allocated
        sq_alloc_tag : out std_logic_vector(integer(ceil(log2(real(SQ_ENTRIES)))) - 1 downto 0);
        lq_alloc_tag : out std_logic_vector(integer(ceil(log2(real(LQ_ENTRIES)))) - 1 downto 0);
        
        sq_data_tag : in std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);       
        lq_dest_tag : in std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        
        sq_full : out std_logic;
        lq_full : out std_logic;
        
        sq_enqueue_en : in std_logic;
        
        -- Tag of the instruction that has been retired in this cycle
        sq_retire_tag : in std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        sq_retire_tag_valid : in std_logic;
        
        lq_enqueue_en : in std_logic;
        lq_retire_en : in std_logic;
        
        -- TEMPORARY BUS STUFF
        cache_read_addr : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        cache_read_data : in std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        cache_read_valid : out std_logic;
        cache_read_ready : in std_logic;
        cache_read_hit : in std_logic;
        cache_read_miss : in std_logic;
        
        cache_write_addr : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        cache_write_data : out std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        cache_write_size : out std_logic_vector(1 downto 0);
        cache_write_valid : out std_logic;
        cache_write_ready : in std_logic;
        cache_write_hit : in std_logic;
        cache_write_miss : in std_logic;
        
        loaded_cacheline_tag : in std_logic_vector(DCACHE_TAG_SIZE - 1 downto 0);
        loaded_cacheline_tag_valid : in std_logic;

        reset : in std_logic;
        clk : in std_logic
    );
end load_store_unit_cache;

architecture rtl of load_store_unit_cache is
    constant DATA_TAG_BITS : integer := PHYS_REGFILE_ADDR_BITS;

    constant SQ_TAG_BITS : integer := integer(ceil(log2(real(SQ_ENTRIES))));
    constant LQ_TAG_BITS : integer := integer(ceil(log2(real(LQ_ENTRIES))));
    constant SQ_ENTRY_BITS : integer := CPU_ADDR_WIDTH_BITS + PHYS_REGFILE_ADDR_BITS + CPU_DATA_WIDTH_BITS + 6;
    constant LQ_ENTRY_BITS : integer := CPU_ADDR_WIDTH_BITS + DATA_TAG_BITS + SQ_ENTRIES + INSTR_TAG_BITS + BRANCHING_DEPTH + 6;

    -- SQ ENTRY INDEXES
    constant SQ_ADDR_VALID : integer := SQ_ENTRY_BITS - 1;
    constant SQ_ADDR_START : integer := SQ_ENTRY_BITS - 2;
    constant SQ_ADDR_END : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - 1;
    constant SQ_DATA_TAG_START : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - 2;
    constant SQ_DATA_TAG_END : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - 1;
    constant SQ_DATA_VALID : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - 2;
    constant SQ_DATA_START : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - 3;
    constant SQ_DATA_END : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - CPU_DATA_WIDTH_BITS - 2;
    constant SQ_SIZE_START : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - CPU_DATA_WIDTH_BITS - 3;
    constant SQ_SIZE_END : integer := SQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - CPU_DATA_WIDTH_BITS - 2 - 2;
    constant SQ_RETIRED_BIT : integer := 1;
    constant SQ_FINISHED_BIT : integer := 0;
    
    -- LQ ENTRY INDEXES
    constant LQ_ADDR_VALID : integer := LQ_ENTRY_BITS - 1;
    constant LQ_ADDR_START : integer := LQ_ENTRY_BITS - 2;
    constant LQ_ADDR_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - 1;
    constant LQ_DATA_TAG_START : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - 2;
    constant LQ_DATA_TAG_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - 1;
    constant LQ_STQ_MASK_START : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - 2;
    constant LQ_STQ_MASK_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - 1;
    constant LQ_INSTR_TAG_START : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - 2;
    constant LQ_INSTR_TAG_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 1;
    constant LQ_SIZE_START : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 2;
    constant LQ_SIZE_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 2 - 1;
    constant LQ_BRMASK_START : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 2 - 2;
    constant LQ_BRMASK_END : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 2 - BRANCHING_DEPTH - 1;
    constant LQ_IS_UNSIGNED_BIT : integer := LQ_ENTRY_BITS - CPU_ADDR_WIDTH_BITS - DATA_TAG_BITS - SQ_ENTRIES - INSTR_TAG_BITS - 2 - BRANCHING_DEPTH - 2;
    constant LQ_EXECUTED_BIT : integer := 1;
    constant LQ_VALID_BIT : integer := 0;

    -- INITIALIZATION CONSTANTS
    constant SQ_ZERO_PART : std_logic_vector(SQ_ENTRY_BITS - 3 downto 0) := (others => '0');
    constant SQ_INIT : std_logic_vector(SQ_ENTRY_BITS - 1 downto 0) := SQ_ZERO_PART & "11";      -- Set starting value of retired bits of SQ entries to 1
    
    constant LQ_STQ_MASK_ZERO : std_logic_vector(SQ_ENTRIES - 1 downto 0) := (others => '0');

    type sq_type is array(SQ_ENTRIES - 1 downto 0) of std_logic_vector(SQ_ENTRY_BITS - 1 downto 0);     -- [ADDR VALID | ADDRESS | DATA SRC TAG | DATA VALID | DATA | RETIRED | FINISHED]
    type lq_type is array(LQ_ENTRIES - 1 downto 0) of std_logic_vector(LQ_ENTRY_BITS - 1 downto 0);     -- [ADDR VALID | ADDRESS | DATA DEST TAG | STQ MASK BITS | READY | EXECUTED | VALID]
    
    signal store_queue : sq_type;
    signal load_queue : lq_type;
    
    -- STORE QUEUE HEAD AND TAIL COUNTER REGISTERS AND MISPREDICTION RECOVERY MEMORY
    signal sq_head_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_head_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    
    type sq_tail_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_mispredict_recovery_memory : sq_tail_mispredict_recovery_memory_type;
    -- LOAD QUEUE HEAD AND TAIL COUNTER REGISTERS AND MISPREDICTION RECOVERY MEMORY
    signal lq_head_counter_reg : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_head_counter_next : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_counter_reg : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_counter_next : unsigned(LQ_TAG_BITS - 1 downto 0);
    
    type lq_tail_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_mispredict_recovery_memory : lq_tail_mispredict_recovery_memory_type;
    -- LOAD QUEUE ENTRY ALLOCATION LOGIC
    signal lq_mask_bits : std_logic_vector(SQ_ENTRIES - 1 downto 0);
    
    -- CONTROL SIGNALS
    signal sq_finished_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
    signal sq_finished_tag_valid : std_logic;
    
    signal sq_store_ready : std_logic;
    signal lq_ready_loads : std_logic_vector(LQ_ENTRIES - 1 downto 0);
    signal lq_load_ready : std_logic;
    --signal lq_selected_index : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
    
    signal sq_dequeue_en : std_logic;
    
    signal i_sq_full : std_logic;
    signal sq_empty : std_logic;
    
    signal i_lq_full : std_logic;
    signal lq_empty : std_logic;
    
    signal load_data_decoded : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal load_data_reg : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    signal load_data_reg_en : std_logic;
    
    signal load_wait_tag : std_logic_vector(DCACHE_TAG_SIZE - 1 downto 0);
    signal load_wait : std_logic;
    
    signal store_wait_tag : std_logic_vector(DCACHE_TAG_SIZE - 1 downto 0);
    signal store_wait : std_logic;
    
    signal spec_br_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);

    -- STATE MACHINES
    type store_state_type is (STORE_IDLE,
                              STORE_BUSY,
                              STORE_FINALIZE);
                              
    signal store_state_reg : store_state_type;
    signal store_state_next : store_state_type;
                              
    type load_state_type is (LOAD_IDLE,
                             LOAD_BUSY,
                             LOAD_WRITEBACK);
                             
    signal load_state_reg : load_state_type;
    signal load_state_next : load_state_type;
begin
--    lq_select_ready_prioenc : entity work.priority_encoder(rtl)
--                              generic map(NUM_INPUTS => LQ_ENTRIES,
--                                          HIGHER_INPUT_HIGHER_PRIO => false)
--                              port map(d => lq_ready_loads,
--                                       q => lq_selected_index,
--                                       valid => lq_load_ready);

    -- STATE MACHINES
    store_state_reg_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                store_state_reg <= STORE_IDLE;
            else
                store_state_reg <= store_state_next;
            end if;
        end if;
    end process;

    store_next_state_proc : process(store_state_reg, sq_store_ready, cache_write_ready, cache_write_hit, cache_write_miss)
    begin
        case store_state_reg is
            when STORE_IDLE => 
                if (sq_store_ready = '1' and cache_write_ready = '1' and store_wait = '0') then
                    store_state_next <= STORE_BUSY;
                else
                    store_state_next <= STORE_IDLE;
                end if;
            when STORE_BUSY =>
                if (cache_write_hit = '1') then
                    store_state_next <= STORE_FINALIZE;
                elsif (cache_write_miss = '1') then
                    store_state_next <= STORE_IDLE;
                else
                    store_state_next <= STORE_BUSY;
                end if;
            when STORE_FINALIZE => 
                store_state_next <= STORE_IDLE;
        end case;
    end process;

    process(store_queue, sq_head_counter_reg)
    begin
        cache_write_addr <= store_queue(to_integer(sq_head_counter_reg))(SQ_ADDR_START downto SQ_ADDR_END);
        cache_write_data <= store_queue(to_integer(sq_head_counter_reg))(SQ_DATA_START downto SQ_DATA_END);
        cache_write_size <= store_queue(to_integer(sq_head_counter_reg))(SQ_SIZE_START downto SQ_SIZE_END);
    end process;
    
    wait_on_miss_cntrl : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                store_wait_tag <= (others => '0');
                store_wait <= '0';
                
                load_wait_tag <= (others => '0');
                load_wait <= '0';
            else
                if (store_state_reg = STORE_BUSY and cache_write_miss = '1') then
                    store_wait_tag <= store_queue(to_integer(sq_head_counter_reg))(SQ_ADDR_START downto SQ_ADDR_START - DCACHE_TAG_SIZE + 1);
                    store_wait <= '1';
                elsif (store_wait_tag = loaded_cacheline_tag and loaded_cacheline_tag_valid = '1') then
                    store_wait <= '0';
                end if;
                
                if (load_state_reg = LOAD_BUSY and cache_read_miss = '1') then
                    load_wait_tag <= load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_START downto LQ_ADDR_START - DCACHE_TAG_SIZE + 1);
                    load_wait <= '1';
                elsif (load_wait_tag = loaded_cacheline_tag and loaded_cacheline_tag_valid = '1') then
                    load_wait <= '0';
                end if;
            end if; 
        end if;
    end process;
    
    store_state_outputs_proc : process(all)
    begin
        sq_finished_tag_valid <= '0';
        sq_dequeue_en <= '0';
        cache_write_valid <= '0';

        case store_state_reg is
            when STORE_IDLE =>
                cache_write_valid <= sq_store_ready and not store_wait;
            when STORE_BUSY =>
                
            when STORE_FINALIZE => 
                sq_finished_tag_valid <= '1';
                sq_dequeue_en <= '1';
        end case;
    end process;

    load_next_state_proc : process(load_state_reg, lq_load_ready, cdb_granted, load_wait, cache_read_ready, cache_read_hit, cache_read_miss)
    begin
        load_state_next <= LOAD_IDLE;
        case load_state_reg is
            when LOAD_IDLE => 
                if (lq_load_ready = '1' and load_wait = '0' and cache_read_ready = '1') then
                    load_state_next <= LOAD_BUSY;
                else
                    load_state_next <= LOAD_IDLE;
                end if;
            when LOAD_BUSY =>
                if (cache_read_hit = '1') then
                    load_state_next <= LOAD_WRITEBACK;
                elsif (cache_read_miss = '1') then
                    load_state_next <= LOAD_IDLE;
                else
                    load_state_next <= LOAD_BUSY;
                end if;
            when LOAD_WRITEBACK =>
                if (cdb_granted = '1') then
                    load_state_next <= LOAD_IDLE;
                else
                    load_state_next <= LOAD_WRITEBACK;
                end if;
        end case;
    end process;
    
    process(all)
    begin
        cache_read_addr <= load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_START downto LQ_ADDR_END);
    end process;
    
    load_state_outputs_proc : process(load_state_reg, cdb_in, load_wait, lq_load_ready)
    begin

        cdb_request <= '0';
        cdb_out.valid <= '0';
        load_data_reg_en <= '0';
        cache_read_valid <= '0';
        case load_state_reg is
            when LOAD_IDLE => 
                cache_read_valid <= lq_load_ready and not load_wait;
            when LOAD_BUSY => 
                load_data_reg_en <= '1';
            when LOAD_WRITEBACK => 
                    cdb_request <= '1';
                    cdb_out.valid <= '1';
        end case;
    end process;
    
    load_state_reg_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                load_state_reg <= LOAD_IDLE;
            else
                if (cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1' and 
                   (((load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_BRMASK_START downto LQ_BRMASK_END) and cdb_in.branch_mask)) /= BRANCH_MASK_ZERO)) then
                    load_state_reg <= LOAD_IDLE;
                else
                    load_state_reg <= load_state_next;
                end if;
            end if;
        end if;
    end process;

    spec_br_mask <= next_uop.speculated_branches_mask when cdb_in.valid = '0' else next_uop.speculated_branches_mask and not cdb_in.branch_mask;
    -- QUEUE CONTROL
    queue_control_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                store_queue <= (others => SQ_INIT);
                load_queue <= (others => (others => '0'));
            else
                if (next_uop.branch_mask /= BRANCH_MASK_ZERO and next_uop_valid = '1') then
                    lq_tail_mispredict_recovery_memory(branch_mask_to_int(next_uop.branch_mask)) <= lq_tail_counter_reg;
                end if;
                
                if (next_uop.branch_mask /= BRANCH_MASK_ZERO and next_uop_valid = '1') then
                    sq_tail_mispredict_recovery_memory(branch_mask_to_int(next_uop.branch_mask)) <= sq_tail_counter_reg;
                end if;
            
                if (sq_enqueue_en = '1' and i_sq_full = '0') then
                    store_queue(to_integer(sq_tail_counter_reg)) <= '0' &         
                                                                    ADDR_ZERO &   
                                                                    sq_data_tag & 
                                                                    '0' &         
                                                                    DATA_ZERO &
                                                                    next_uop.operation_select(1 downto 0) & 
                                                                    '0' &
                                                                    '0';             
                end if;
                
                for i in 0 to LQ_ENTRIES - 1 loop
                    if (to_integer(unsigned(lq_calc_addr_tag)) = i and lq_calc_addr_valid = '1') then
                        load_queue(i)(LQ_ADDR_START downto LQ_ADDR_END) <= generated_address;
                        load_queue(i)(LQ_ADDR_VALID) <= '1';
                    end if;
                    
                    if (sq_finished_tag_valid = '1') then
                        load_queue(i)(to_integer(unsigned(sq_finished_tag)) + LQ_STQ_MASK_END) <= '0';
                    end if;
                    
                    if (cdb_in.valid = '1') then
                        load_queue(i)(LQ_BRMASK_START downto LQ_BRMASK_END) <= load_queue(i)(LQ_BRMASK_START downto LQ_BRMASK_END) and not cdb_in.branch_mask;
                    end if;
                end loop;
                
                if (lq_enqueue_en = '1' and i_lq_full = '0') then
                    load_queue(to_integer(lq_tail_counter_reg)) <= '0' &
                                                                   ADDR_ZERO &
                                                                   lq_dest_tag &
                                                                   lq_mask_bits &
                                                                   instr_tag & 
                                                                   next_uop.operation_select(1 downto 0) &
                                                                   spec_br_mask &
                                                                   next_uop.operation_select(2) &
                                                                   '0' &
                                                                   '1';
                end if;
                
                if (sq_retire_tag_valid = '1') then
                    store_queue(to_integer(unsigned(sq_retire_tag)))(SQ_RETIRED_BIT) <= '1';
                end if;
                
                if (sq_dequeue_en = '1') then
                    store_queue(to_integer(sq_head_counter_reg))(SQ_FINISHED_BIT) <= '1';
                end if;
                
                if (cdb_granted = '1' and not (cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1')) then
                    load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_VALID_BIT) <= '0';
                end if;
                                                                   
                for i in 0 to SQ_ENTRIES - 1 loop
                    if (to_integer(unsigned(sq_calc_addr_tag)) = i and sq_calc_addr_valid = '1') then
                        store_queue(i)(SQ_ADDR_START downto SQ_ADDR_END) <= generated_address;
                        store_queue(i)(SQ_ADDR_VALID) <= '1';
                    end if;
                    
                    if (sq_store_data_tag = store_queue(i)(SQ_DATA_TAG_START downto SQ_DATA_TAG_END) and sq_store_data_valid = '1') then
                        store_queue(i)(SQ_DATA_START downto SQ_DATA_END) <= sq_store_data;
                        store_queue(i)(SQ_DATA_VALID) <= '1';
                    end if;
                end loop;
              
            end if;
        end if;
    end process;
    
--    load_ready_proc : process(load_queue)
--    begin
--        for i in 0 to LQ_ENTRIES - 1 loop
--            if (load_queue(i)(LQ_STQ_MASK_START downto LQ_STQ_MASK_END) = LQ_STQ_MASK_ZERO and load_queue(i)(LQ_ADDR_VALID) = '1' and load_queue(i)(LQ_VALID_BIT) = '1') then
--                lq_ready_loads(i) <= '1';
--            else
--                lq_ready_loads(i) <= '0';
--            end if;
--        end loop;
--    end process;

    queue_counters_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                sq_head_counter_reg <= (others => '0');
                sq_tail_counter_reg <= (others => '0');
                
                lq_head_counter_reg <= (others => '0');
                lq_tail_counter_reg <= (others => '0');
                
                load_data_reg <= (others => '0');
            else
                if ((sq_enqueue_en = '1' and i_sq_full = '0') or (cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1')) then
                    sq_tail_counter_reg <= sq_tail_counter_next;
                end if;
                
                if (sq_dequeue_en = '1' and sq_empty = '0') then
                    sq_head_counter_reg <= sq_head_counter_next;
                end if;
                
                if ((lq_enqueue_en = '1' and i_lq_full = '0') or (cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1')) then
                    lq_tail_counter_reg <= lq_tail_counter_next;
                end if;
                
                if (lq_retire_en = '1' and lq_empty = '0') then
                    lq_head_counter_reg <= lq_head_counter_next;
                end if;
                
                if (load_data_reg_en = '1') then
                    load_data_reg <= load_data_decoded;
                end if;
            end if;
        end if;
    end process;
    
    sq_head_counter_next <= (others => '0') when sq_head_counter_reg = SQ_ENTRIES - 1 else
                            sq_head_counter_reg + 1;
                            
    sq_tail_counter_next <= sq_tail_mispredict_recovery_memory(branch_mask_to_int(cdb_in.branch_mask)) when cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1' else  
                            (others => '0') when sq_tail_counter_reg = SQ_ENTRIES - 1 else
                            sq_tail_counter_reg + 1;
                            
    lq_head_counter_next <= (others => '0') when lq_head_counter_reg = LQ_ENTRIES - 1 else
                            lq_head_counter_reg + 1;
                            
    lq_tail_counter_next <= lq_tail_mispredict_recovery_memory(branch_mask_to_int(cdb_in.branch_mask)) when cdb_in.branch_mispredicted = '1' and cdb_in.valid = '1' else 
                            (others => '0') when lq_tail_counter_reg = LQ_ENTRIES - 1 else
                            lq_tail_counter_reg + 1;
              
    -- ============================ LOAD INSTRUCTION ALLOCATION LOGIC ============================
    process(lq_enqueue_en, store_queue, sq_tail_counter_reg, sq_head_counter_reg, sq_finished_tag, sq_finished_tag_valid)
    begin
        if (lq_enqueue_en = '1') then
            for i in 0 to SQ_ENTRIES - 1 loop
                if (sq_finished_tag_valid = '1' and unsigned(sq_finished_tag) = i) then
                    lq_mask_bits(i) <= '0';
                elsif (sq_head_counter_reg > sq_tail_counter_reg) then
                    lq_mask_bits(i) <= not store_queue(i)(0) when i < sq_tail_counter_reg or i >= sq_head_counter_reg else '0';
                elsif (sq_head_counter_reg < sq_tail_counter_reg) then
                    lq_mask_bits(i) <= not store_queue(i)(0) when i < sq_tail_counter_reg and i >= sq_head_counter_reg else '0';
                else
                    lq_mask_bits(i) <= '0';    
                end if;
            end loop;
        else
            lq_mask_bits <= (others => '0');
        end if;
    end process;
    
    -- ===========================================================================================
    
    -- ============================ READ BUS DATA DECODING ============================
    process(all)
    begin
        load_data_decoded(31 downto 0) <= (others => '0');     
        if (load_queue(to_integer(lq_head_counter_reg))(LQ_SIZE_START downto LQ_SIZE_END) = "00") then                  -- LB
            if (load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_END + 1 downto LQ_ADDR_END) = "00") then
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 8) <= (others => cache_read_data(7));   
                end if;
                load_data_decoded(7 downto 0) <= cache_read_data(7 downto 0);
            elsif (load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_END + 1 downto LQ_ADDR_END) = "01") then
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 8) <= (others => cache_read_data(15));   
                end if;
                load_data_decoded(7 downto 0) <= cache_read_data(15 downto 8);
            elsif (load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_END + 1 downto LQ_ADDR_END) = "10") then
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 8) <= (others => cache_read_data(23));   
                end if;
                load_data_decoded(7 downto 0) <= cache_read_data(23 downto 16);
            elsif (load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_END + 1 downto LQ_ADDR_END) = "11") then
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 8) <= (others => cache_read_data(31));   
                end if;
                load_data_decoded(7 downto 0) <= cache_read_data(31 downto 24);
            end if;
        elsif (load_queue(to_integer(lq_head_counter_reg))(LQ_SIZE_START downto LQ_SIZE_END) = "01") then
            if (load_queue(to_integer(lq_head_counter_reg))(LQ_ADDR_END + 1) = '0') then
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 16) <= (others => cache_read_data(15));   
                end if;
                load_data_decoded(15 downto 0) <= cache_read_data(15 downto 0);
            else
                if (load_queue(to_integer(lq_head_counter_reg))(LQ_IS_UNSIGNED_BIT) = '0') then
                    load_data_decoded(31 downto 16) <= (others => cache_read_data(31));   
                end if;
                load_data_decoded(15 downto 0) <= cache_read_data(31 downto 16);
            end if;
        elsif (load_queue(to_integer(lq_head_counter_reg))(LQ_SIZE_START downto LQ_SIZE_END) = "10") then  
                load_data_decoded <= cache_read_data;
        else
            load_data_decoded(31 downto 0) <= (others => '0');
        end if;
    end process;
    -- ===========================================================================================
    
    
    sq_finished_tag <= std_logic_vector(sq_head_counter_reg);                 
    -- A store instruction can issue a write to memory when the address is valid, data is valid AND it has been retired in the ROB
    sq_store_ready <= '1' when store_queue(to_integer(sq_head_counter_reg))(SQ_ADDR_VALID) = '1' and 
                               store_queue(to_integer(sq_head_counter_reg))(SQ_DATA_VALID) = '1' and 
                               store_queue(to_integer(sq_head_counter_reg))(SQ_RETIRED_BIT) = '1' and
                               store_queue(to_integer(sq_head_counter_reg))(SQ_FINISHED_BIT) = '0' else '0';
                            
    i_sq_full <= '1' when sq_tail_counter_next = sq_head_counter_reg else '0';
    i_lq_full <= '1' when lq_tail_counter_next = lq_head_counter_reg else '0';
    
    sq_empty <= '1' when sq_head_counter_reg = sq_tail_counter_reg else '0';
    lq_empty <= '1' when lq_head_counter_reg = lq_tail_counter_reg else '0';
    
    sq_full <= i_sq_full;
    lq_full <= i_lq_full;
    
    sq_alloc_tag <= std_logic_vector(sq_tail_counter_reg);
    lq_alloc_tag <= std_logic_vector(lq_tail_counter_reg);
                 
    cdb_out.pc_low_bits <= (others => '0');
    cdb_out.data <= load_data_reg;
    cdb_out.target_addr <= (others => '0');
    cdb_out.phys_dest_reg <= load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_DATA_TAG_START downto LQ_DATA_TAG_END);
    cdb_out.instr_tag <= load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_INSTR_TAG_START downto LQ_INSTR_TAG_END);
    cdb_out.branch_mask <= (others => '0');
    cdb_out.branch_mispredicted <= '0';
    cdb_out.is_jalr <= '0';
    cdb_out.branch_taken <= '0';
    
    lq_load_ready <= '1' when load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_STQ_MASK_START downto LQ_STQ_MASK_END) = LQ_STQ_MASK_ZERO and 
                              (load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_BRMASK_START downto LQ_BRMASK_END) = BRANCH_MASK_ZERO or load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_ADDR_START downto LQ_ADDR_END) < NONCACHEABLE_BASE_ADDR) and
                              load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_ADDR_VALID) = '1' and load_queue(to_integer(unsigned(lq_head_counter_reg)))(LQ_VALID_BIT) = '1' and
                               lq_empty = '0' else '0';
    
end rtl;

