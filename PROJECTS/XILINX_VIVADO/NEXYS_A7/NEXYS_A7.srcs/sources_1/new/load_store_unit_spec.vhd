library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.PKG_CPU.ALL;

-- Implements a LSU which supports speculative execution of load instructions. Store instructions are executed in order. 

entity load_store_unit_spec is
    port(
        cdb_branch : in cdb_single_type;
        cdb_out : out cdb_single_type;
        cdb_request : out std_logic;
        cdb_granted : in std_logic;
        
        rob_head_in : in rob_head_type;
        
        uop_in : uop_full_type;
        uop_in_valid : std_logic;
        
        addr_data_gen_in : lsu_spec_input_type;
        
        sq_full : out std_logic;
        sq_empty : out std_logic;
        
        lq_full : out std_logic;
        lq_empty : out std_logic;
        
        to_cache : out cache_in_type;
        from_cache : in cache_out_type;
        
        reset : in std_logic;
        clk : in std_logic
    );
end load_store_unit_spec;

architecture Behavioral of load_store_unit_spec is
    -- STORE QUEUE
    constant SQ_NUM_ELEMENTS_MAX : unsigned(SQ_TAG_BITS downto 0) := to_unsigned(SQ_ENTRIES, SQ_TAG_BITS + 1);
    constant SQ_NUM_ELEMENTS_MIN : unsigned(SQ_TAG_BITS downto 0) := to_unsigned(0, SQ_TAG_BITS + 1);
    
    type sq_type is array (0 to SQ_ENTRIES - 1) of lsu_spec_sq_entry_type;
    signal store_queue : sq_type;
    signal dispatched_store : lsu_spec_sq_entry_type;
    
    signal sq_enqueue : std_logic;
    signal sq_dequeue : std_logic;
    signal sq_dispatch : std_logic;
    signal sq_dispatch_ready : std_logic;
    
    signal sq_head_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_head_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_num_elements : unsigned(SQ_TAG_BITS downto 0);
    type sq_tail_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_mispredict_recovery_memory : sq_tail_mispredict_recovery_memory_type;
    type sq_num_elements_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(SQ_TAG_BITS downto 0);
    signal sq_num_elements_mispredict_recovery_memory : sq_num_elements_mispredict_recovery_memory_type;
    
    -- LOAD QUEUE
    type lq_type is array (0 TO LQ_ENTRIES - 1) of lsu_spec_lq_entry_type;
    signal load_queue : lq_type;
    signal dispatched_load : lsu_spec_lq_entry_type;
    
    signal lq_enqueue : std_logic;
    signal lq_dequeue : std_logic;
    signal lq_dispatch : std_logic;
    signal lq_dispatch_ready : std_logic;
    
    signal lq_head_counter_reg : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_head_counter_next : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_counter_reg : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_counter_next : unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_num_elements : unsigned(SQ_TAG_BITS downto 0);
    type lq_tail_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(LQ_TAG_BITS - 1 downto 0);
    signal lq_tail_mispredict_recovery_memory : lq_tail_mispredict_recovery_memory_type;
    type lq_num_elements_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(LQ_TAG_BITS downto 0);
    signal lq_num_elements_mispredict_recovery_memory : lq_num_elements_mispredict_recovery_memory_type;
    
    signal lq_curr_store_mask : std_logic_vector(SQ_ENTRIES - 1 downto 0);
    
    signal lq_dispatch_load_index : unsigned(LQ_TAG_BITS - 1 downto 0);
    
    -- PIPELINE REGS
    type pipeline_reg_0_type is record
        address : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        size : std_logic_vector(1 downto 0);
        lq_tag : std_logic_vector(LQ_TAG_BITS - 1 downto 0);
        sq_mask : std_logic_vector(SQ_ENTRIES - 1 downto 0);
        cacheop : std_logic_vector(1 downto 0);
        spec : std_logic;
        is_store : std_logic;
        valid : std_logic;
    end record;
    
    type pipeline_reg_1_type is record
        address : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        size : std_logic_vector(1 downto 0);
        lq_tag : std_logic_vector(LQ_TAG_BITS - 1 downto 0);
        sq_mask : std_logic_vector(SQ_ENTRIES - 1 downto 0);
        cacheop : std_logic_vector(1 downto 0);
        spec : std_logic;
        is_store : std_logic;
        valid : std_logic;
    end record;
    
    type pipeline_reg_2_type is record
        data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        phys_dest_reg : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        valid : std_logic;
    end record;
    
    signal pipeline_reg_0 : pipeline_reg_0_type;
    signal pipeline_reg_1 : pipeline_reg_1_type;
    signal pipeline_reg_2 : pipeline_reg_2_type;
    
    -- OTHERS 
    signal address_match_bits_1 : std_logic_vector(SQ_ENTRIES - 1 downto 0);
    signal address_match_bits_2 : std_logic_vector(SQ_ENTRIES - 1 downto 0);
    signal redo_load : std_logic; 
    
    signal stall_0 : std_logic;
    signal stall_1 : std_logic;
    
    signal read_dispatch_to_cache : std_logic;
    signal write_dispatch_to_cache : std_logic;
    
    signal load_data_decoded : std_logic_vector(31 downto 0);
    signal load_data_reg : std_logic_vector(31 downto 0);
begin
    -- ================================================================================================
    -- ////////////////////////////////////////// STORES //////////////////////////////////////////////
    -- ================================================================================================
    sq_enqueue <= '1' when uop_in_valid = '1' and uop_in.operation_type = OPTYPE_STORE and sq_full = '0' else '0';
    sq_dequeue <= '1' when dispatched_store.retired = '1' and sq_empty = '0' else '0';
    sq_dispatch_ready <= '1' when dispatched_store.retired = '1' and 
                                  dispatched_store.address_valid = '1' and
                                  dispatched_store.data_valid = '1' and
                                  sq_empty = '0' and
                                  stall_0 = '0' else '0';
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                sq_num_elements <= to_unsigned(0, SQ_TAG_BITS + 1);
                sq_tail_counter_reg <= to_unsigned(0, SQ_TAG_BITS);
                sq_head_counter_reg <= to_unsigned(0, SQ_TAG_BITS);
            else
                if (cdb_branch.valid = '1' and cdb_branch.branch_mispredicted = '1') then
                    sq_tail_counter_reg <= sq_tail_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask));
                    
                    if (sq_dequeue = '1') then
                        sq_num_elements <= sq_num_elements_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask)) - 1;
                    else
                        sq_num_elements <= sq_num_elements_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask));
                    end if;
                else
                    if (sq_enqueue = '1') then
                        sq_tail_counter_reg <= sq_tail_counter_next;
                        sq_num_elements <= sq_num_elements + 1;
                    end if;
                
                    if (sq_dequeue = '1') then
                        sq_num_elements <= sq_num_elements - 1;
                    end if;
                end if;
                
                if (sq_dequeue = '1') then
                    sq_head_counter_reg <= sq_head_counter_next;
                end if;
            end if;
        end if;
    end process;
    
    process(all)
    begin
        if (sq_tail_counter_reg = SQ_ENTRIES - 1) then
            sq_tail_counter_next <= to_unsigned(0, SQ_TAG_BITS);
        else
            sq_tail_counter_next <= sq_tail_counter_reg + 1;
        end if;
        
        if (sq_head_counter_reg = SQ_ENTRIES - 1) then
            sq_head_counter_next <= to_unsigned(0, SQ_TAG_BITS);
        else
            sq_head_counter_next <= sq_head_counter_reg + 1;
        end if;
    end process;

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to SQ_ENTRIES - 1 loop
                    store_queue(i).valid <= '0';
                end loop;
            else
                if (sq_enqueue = '1') then
                    store_queue(to_integer(sq_tail_counter_reg)).address_valid <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).data_valid <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).is_cmo <= uop_in.operation_select(6);
                    store_queue(to_integer(sq_tail_counter_reg)).cmo_opcode <= uop_in.operation_select(4 downto 3);
                    store_queue(to_integer(sq_tail_counter_reg)).size <= uop_in.operation_select(1 downto 0);
                    store_queue(to_integer(sq_tail_counter_reg)).retired <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).valid <= '1';
                end if;
                
                if (uop_in_valid = '1' and uop_in.branch_mask /= BRANCH_MASK_ZERO) then
                    sq_tail_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= sq_tail_counter_reg;
                    sq_num_elements_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= sq_num_elements;
                end if;
                
                -- Snapshots of num elements still have to be reduced by 1 when a store is dequeued since they hold how many stores would be in the SQ
                -- if we didn't fetch any instructions after the speculated branch
                if (sq_dequeue = '1') then
                    for i in 0 to BRANCHING_DEPTH - 1 loop  
                        sq_num_elements_mispredict_recovery_memory(i) <= sq_num_elements_mispredict_recovery_memory(i) - 1;
                    end loop;
                    
                    store_queue(to_integer(unsigned(sq_head_counter_reg))).valid <= '0';
                end if;
                
                if (rob_head_in.retire = '1' and rob_head_in.operation_type = OPTYPE_STORE) then
                    store_queue(to_integer(unsigned(rob_head_in.sq_tag))).retired <= '1';
                end if;
                
                if (addr_data_gen_in.is_store = '1') then
                    if (addr_data_gen_in.generated_address_valid = '1') then
                        store_queue(to_integer(unsigned(addr_data_gen_in.sq_tag))).address <= addr_data_gen_in.generated_address;
                        store_queue(to_integer(unsigned(addr_data_gen_in.sq_tag))).address_valid <= '1';
                    end if;
                    
                    if (addr_data_gen_in.generated_data_valid = '1') then
                        store_queue(to_integer(unsigned(addr_data_gen_in.sq_tag))).data <= addr_data_gen_in.generated_data;
                        store_queue(to_integer(unsigned(addr_data_gen_in.sq_tag))).data_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    dispatched_store <= store_queue(to_integer(sq_head_counter_reg));
    
    sq_empty <= '1' when sq_num_elements = 0 else '0';
    sq_full <= '1' when sq_num_elements = SQ_ENTRIES else '0';

    -- ================================================================================================
    -- ////////////////////////////////////////// LOADS //////////////////////////////////////////////
    -- ================================================================================================
    lq_enqueue <= '1' when uop_in_valid = '1' and uop_in.operation_type = OPTYPE_LOAD and lq_full = '0' else '0';
    --lq_dequeue <= '1' when load_queue(to_integer(lq_head_counter_reg)).executed = '1' and 
    --                  load_queue(to_integer(lq_head_counter_reg)).store_mask = STORE_MASK_ZERO else '0';
    lq_dequeue <= 'X';
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                lq_num_elements <= to_unsigned(0, LQ_TAG_BITS + 1);
                lq_tail_counter_reg <= to_unsigned(0, LQ_TAG_BITS);
                lq_head_counter_reg <= to_unsigned(0, LQ_TAG_BITS);
            else
                if (cdb_branch.valid = '1' and cdb_branch.branch_mispredicted = '1') then
                    lq_tail_counter_reg <= lq_tail_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask));
                    
                    if (lq_dequeue = '1') then
                        lq_num_elements <= lq_num_elements_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask)) - 1;
                    else
                        lq_num_elements <= lq_num_elements_mispredict_recovery_memory(branch_mask_to_int(cdb_branch.branch_mask));
                    end if;
                else
                    if (lq_enqueue = '1') then
                        lq_tail_counter_reg <= lq_tail_counter_next;
                        lq_num_elements <= lq_num_elements + 1;
                    end if;
                
                    if (lq_dequeue = '1') then
                        lq_num_elements <= lq_num_elements - 1;
                    end if;
                end if;
                
                if (lq_dequeue = '1') then
                    lq_head_counter_reg <= lq_head_counter_next;
                end if;
            end if;
        end if;
    end process;
    
    process(all)
    begin
        if (lq_tail_counter_reg = LQ_ENTRIES - 1) then
            lq_tail_counter_next <= to_unsigned(0, LQ_TAG_BITS);
        else
            lq_tail_counter_next <= lq_tail_counter_reg + 1;
        end if;
        
        if (lq_head_counter_reg = LQ_ENTRIES - 1) then
            lq_head_counter_next <= to_unsigned(0, LQ_TAG_BITS);
        else
            lq_head_counter_next <= lq_head_counter_reg + 1;
        end if;
    end process;
    
    lq_cntrl_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to LQ_ENTRIES - 1 loop
                    load_queue(i).valid <= '0';
                end loop;
            else
                if (lq_enqueue = '1') then
                    load_queue(to_integer(lq_tail_counter_reg)).address_valid <= '0';
                    load_queue(to_integer(lq_tail_counter_reg)).instr_tag <= uop_in.instr_tag;
                    load_queue(to_integer(lq_tail_counter_reg)).size <= uop_in.operation_select(1 downto 0);
                    load_queue(to_integer(lq_tail_counter_reg)).store_mask <= lq_curr_store_mask;
                    load_queue(to_integer(lq_tail_counter_reg)).branch_mask <= uop_in.branch_mask;
                    load_queue(to_integer(lq_tail_counter_reg)).is_unsigned <= uop_in.operation_select(2);
                    load_queue(to_integer(lq_tail_counter_reg)).speculate <= uop_in.operation_select(3);
                    load_queue(to_integer(lq_tail_counter_reg)).dispatched <= '0';
                    load_queue(to_integer(lq_tail_counter_reg)).executed <= '0';
                    load_queue(to_integer(lq_tail_counter_reg)).valid <= '1';
                end if;
                
                if (uop_in_valid = '1' and uop_in.branch_mask /= BRANCH_MASK_ZERO) then
                    lq_tail_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= lq_tail_counter_reg;
                    lq_num_elements_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= lq_num_elements;
                end if;
                
                if (lq_dequeue = '1') then
                    for i in 0 to BRANCHING_DEPTH - 1 loop  
                        lq_num_elements_mispredict_recovery_memory(i) <= lq_num_elements_mispredict_recovery_memory(i) - 1;
                    end loop;
                    
                    load_queue(to_integer(lq_head_counter_reg)).valid <= '0';
                end if;
                
                if (addr_data_gen_in.generated_address_valid = '1' and addr_data_gen_in.is_store = '0') then
                    load_queue(to_integer(unsigned(addr_data_gen_in.lq_tag))).address <= addr_data_gen_in.generated_address;
                    load_queue(to_integer(unsigned(addr_data_gen_in.lq_tag))).address_valid <= '1';
                end if;
                
                if (lq_dispatch = '1') then
                    load_queue(to_integer(lq_dispatch_load_index)).dispatched <= '1';
                end if;
                
                -- Updates the load's store mask and will try to re-execute it in the near future
                if (redo_load = '1') then
                    load_queue(to_integer(unsigned(pipeline_reg_1.lq_tag))).store_mask <= pipeline_reg_1.sq_mask;
                    load_queue(to_integer(unsigned(pipeline_reg_1.lq_tag))).dispatched <= '0';
                end if;
                
                if (from_cache.read_ready = '1') then
                    load_queue(to_integer(unsigned(from_cache.read_lq_tag))).executed <= '1';
                end if;
                
                if (cdb_branch.valid = '1') then
                    for i in 0 to LQ_ENTRIES loop
                        load_queue(i).branch_mask <= load_queue(i).branch_mask and not cdb_branch.branch_mask;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    dispatched_load <= load_queue(to_integer(lq_dispatch_load_index));
    
    -- Generates a store mask which will be used as initial value for any incoming loads. The mask has 1's for every valid SQ entry and 0's for empty entries. 
    sq_mask_gen : process(all)
    begin
        lq_curr_store_mask <= (others => '0');
        if (sq_tail_counter_reg > sq_head_counter_reg) then
            for i in 0 to SQ_ENTRIES - 1 loop
                if (i < sq_tail_counter_reg and i >= sq_head_counter_reg) then
                    lq_curr_store_mask(i) <= '1';
                end if;
            end loop;        
        elsif (sq_tail_counter_reg < sq_head_counter_reg) then
            for i in 0 to SQ_ENTRIES - 1 loop
                if (i < sq_tail_counter_reg or i >= sq_head_counter_reg) then
                    lq_curr_store_mask(i) <= '1';
                end if;
            end loop;        
        elsif (sq_num_elements = SQ_NUM_ELEMENTS_MAX) then
                lq_curr_store_mask <= (others => '1');
        end if;
    end process;
    
    -- Selects the next ready load instruction to be sent for execution
    load_scheduler : process(load_queue)
        variable selection : unsigned(LQ_TAG_BITS - 1 downto 0);
        variable valid : std_logic;
    begin
        selection := to_unsigned(0, LQ_TAG_BITS);
        valid := '0';
        for i in LQ_ENTRIES - 1 downto 0 loop
            if (load_queue(i).valid = '1' and 
                load_queue(i).address_valid = '1' and 
                load_queue(i).dispatched = '0' and 
                load_queue(i).executed = '0' and    
                load_queue(i).branch_mask = BRANCH_MASK_ZERO) then              -- TEMPORARILY DISABLE THE EXECUTION OF SPECULATIVE LOAD INSTRUCTIONS TODO: REMOVE
                selection := to_unsigned(i, LQ_TAG_BITS);
                valid := '1';
            end if;
        end loop;
        lq_dispatch_load_index <= selection;
        lq_dispatch_ready <= valid and not stall_0;
    end process;
    
    lq_empty <= '1' when lq_num_elements = 0 else '0';
    lq_full <= '1' when lq_num_elements = LQ_ENTRIES else '0';
    
    -- ================================================================================================
    -- ///////////////////////////////////////// PIPELINE /////////////////////////////////////////////
    -- ================================================================================================
    -- Prioritize stores over loads if both are ready at the same time
    sq_dispatch <= sq_dispatch_ready;           
    lq_dispatch <= lq_dispatch_ready and not sq_dispatch_ready; 
    
    pipeline_reg_0_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_0.valid <= '0';
            else
                if (stall_0 = '0') then
                    if (sq_dispatch = '1') then
                        pipeline_reg_0.address <= dispatched_store.address;
                        pipeline_reg_0.data <= dispatched_store.data;
                        pipeline_reg_0.size <= dispatched_store.size;
                        pipeline_reg_0.lq_tag <= (others => '0');
                        pipeline_reg_0.cacheop <= dispatched_store.cmo_opcode;
                        pipeline_reg_0.branch_mask <= ;
                        pipeline_reg_0.spec <= '0';
                        pipeline_reg_0.is_store <= '1';
                        pipeline_reg_0.valid <= '1';
                    elsif (lq_dispatch = '1') then
                        pipeline_reg_0.address <= dispatched_load.address;
                        pipeline_reg_0.size <= dispatched_load.size;
                        pipeline_reg_0.lq_tag <= std_logic_vector(lq_dispatch_load_index);
                        pipeline_reg_0.sq_mask <= dispatched_load.store_mask;
                        pipeline_reg_0.branch_mask <= ;
                        pipeline_reg_0.spec <= dispatched_load.speculate;
                        pipeline_reg_0.is_store <= '0';
                        pipeline_reg_0.valid <= '1';
                    else
                        pipeline_reg_0.valid <= '0';
                    end if;
                else
                    
                end if;
            end if;
        end if;
    end process;
    
    pipeline_reg_1_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_1.valid <= '0';
            else
                if (stall_1 = '0') then
                    pipeline_reg_1.address <= pipeline_reg_0.address;
                    pipeline_reg_1.data <= pipeline_reg_0.data;
                    pipeline_reg_1.size <= pipeline_reg_0.size;
                    pipeline_reg_1.lq_tag <= pipeline_reg_0.lq_tag;
                    pipeline_reg_1.cacheop <= pipeline_reg_0.cacheop;
                    pipeline_reg_1.is_store <= pipeline_reg_0.is_store;
                    pipeline_reg_1.branch_mask <= ;
                    pipeline_reg_1.spec <= pipeline_reg_0.spec;
                    pipeline_reg_1.valid <= pipeline_reg_0.valid;
                    pipeline_reg_1.sq_mask <= address_match_bits_2;
                else
                
                end if;
            end if;
        end if;
    end process;
    
    pipeline_reg_2_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                pipeline_reg_2.valid <= '0';
            else
                pipeline_reg_2.data <= from_cache.read_data;
                pipeline_reg_2.phys_dest_reg <= from_cache.read_phys_dest_reg;
                pipeline_reg_2.instr_tag <= from_cache.instr_tag;
                pipeline_reg_2.valid <= from_cache.read_ready;
            end if;
        end if;
    end process;
    
    -- ================================================================================================
    -- ///////////////////////////////////////// STAGE 1 //////////////////////////////////////////////
    -- ================================================================================================
    addr_match_detector_proc : process(all)
    begin
        for i in 0 to SQ_ENTRIES - 1 loop
            if (store_queue(i).address_valid = '1' and store_queue(i).valid = '1') then
                case store_queue(i).size is   
                    when LSU_DATA_SIZE_WORD =>
                        address_match_bits_1(i) <= '1' when (store_queue(i).address = (pipeline_reg_0.address and X"FFFF_FFFC")) else '0';
                    when LSU_DATA_SIZE_HALFWORD => 
                        if (pipeline_reg_0.size = LSU_DATA_SIZE_BYTE or pipeline_reg_0.size = LSU_DATA_SIZE_HALFWORD) then
                            address_match_bits_1(i) <= '1' when (store_queue(i).address = (pipeline_reg_0.address and X"FFFF_FFFE")) else '0';
                        else
                            address_match_bits_1(i) <= '1' when ((store_queue(i).address and X"FFFF_FFFC") = pipeline_reg_0.address) else '0';
                        end if;
                    when LSU_DATA_SIZE_BYTE => 
                        if (pipeline_reg_0.size = LSU_DATA_SIZE_BYTE) then
                            address_match_bits_1(i) <= '1' when (store_queue(i).address = pipeline_reg_0.address) else '0';
                        elsif (pipeline_reg_0.size = LSU_DATA_SIZE_HALFWORD) then
                            address_match_bits_1(i) <= '1' when ((store_queue(i).address and X"FFFF_FFFE") = pipeline_reg_0.address) else '0';
                        else
                            address_match_bits_1(i) <= '1' when ((store_queue(i).address and X"FFFF_FFFC") = pipeline_reg_0.address) else '0';
                        end if;
                    when others =>
                        address_match_bits_1(i) <= '0';
                end case;
            elsif (store_queue(i).address_valid = '0' and store_queue(i).valid = '1') then
                address_match_bits_1(i) <= '1';
            else
                address_match_bits_1(i) <= '0';
            end if;
        end loop;
        address_match_bits_2 <= address_match_bits_1 and pipeline_reg_0.sq_mask;        -- AND the produced mask with the dispatched instruction's mask.
                                                                                        -- This removes any matches that have occured with store instructions older then the load.
    end process;
    -- ================================================================================================
    -- ///////////////////////////////////////// STAGE 2 //////////////////////////////////////////////
    -- ================================================================================================
    redo_load <= '1' when pipeline_reg_1.valid = '1' and pipeline_reg_1.is_store = '0' and pipeline_reg_1.spec = '0' and pipeline_reg_1.sq_mask /= std_logic_vector(to_unsigned(0, SQ_ENTRIES)) else '0';
    
    to_cache.read_addr <= pipeline_reg_1.address;
    to_cache.read_size <= pipeline_reg_1.size;
    to_cache.read_valid <= '1' when pipeline_reg_1.valid = '1' and pipeline_reg_1.is_store = '0' and (pipeline_reg_1.spec = '1' or pipeline_reg_1.sq_mask /= std_logic_vector(to_unsigned(0, SQ_ENTRIES))) else '0';
    
    to_cache.write_addr <= pipeline_reg_1.address;
    to_cache.write_data <= pipeline_reg_1.data;
    to_cache.write_size <= pipeline_reg_1.size;
    to_cache.write_cacheop <= pipeline_reg_1.cacheop;
    to_cache.write_valid <= pipeline_reg_1.valid and pipeline_reg_1.is_store;
    
    read_dispatch_to_cache <= '1' when pipeline_reg_1.valid = '1' and pipeline_reg_1.is_store = '0' and (pipeline_reg_1.sq_mask = std_logic_vector(to_unsigned(0, SQ_ENTRIES)) or pipeline_reg_1.spec = '1') else '0';
    write_dispatch_to_cache <= '1' when pipeline_reg_1.valid = '1' and pipeline_reg_1.is_store = '1' else '0';
    stall_1 <= '1' when (read_dispatch_to_cache = '1' and from_cache.read_ready = '0') or (write_dispatch_to_cache = '1' and from_cache.write_ready = '0') else '0';
    stall_0 <= '1' when pipeline_reg_0.valid = '1' and stall_1 = '1' else '0';
   
   -- ================================================================================================
   -- /////////////////////////////////////// DATA READ //////////////////////////////////////////////
   -- ================================================================================================
    cdb_out.pc_low_bits <= (others => '0'); 
    cdb_out.data <= pipeline_reg_2.data;
    cdb_out.target_addr <= (others => '0');
    cdb_out.phys_dest_reg <= pipeline_reg_2.phys_dest_reg;
    cdb_out.instr_tag <= pipeline_reg_2.instr_tag;
    cdb_out.branch_mask <= (others => '0');
    cdb_out.branch_mispredicted <= '0';
    cdb_out.is_jal <= '0';
    cdb_out.is_jalr <= '0';
    cdb_out.branch_taken <= '0';
    cdb_out.valid <= pipeline_reg_2.valid;
    
    cdb_request <= pipeline_reg_2.valid;
   
end Behavioral;

















