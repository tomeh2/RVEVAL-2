library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.PKG_CPU.ALL;

-- Implements a LSU which supports speculative execution of load instructions. Store instructions are executed in order. 

entity load_store_unit_spec is
    port(
        cdb_in : in cdb_type;
        rob_head_in : in rob_head_type;
        
        uop_in : uop_full_type;
        uop_in_valid : std_logic;
        
        sq_full : out std_logic;
        sq_empty : out std_logic;
        
        reset : in std_logic;
        clk : in std_logic
    );
end load_store_unit_spec;

architecture Behavioral of load_store_unit_spec is
    type sq_type is array (0 to SQ_ENTRIES - 1) of lsu_spec_sq_entry_type;
    signal store_queue : sq_type;
    
    signal sq_enqueue : std_logic;
    signal sq_dequeue : std_logic;
    signal sq_dispatch : std_logic;
    
    signal sq_head_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_head_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_reg : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_counter_next : unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_num_elements : unsigned(SQ_TAG_BITS downto 0);
    type sq_tail_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(SQ_TAG_BITS - 1 downto 0);
    signal sq_tail_mispredict_recovery_memory : sq_tail_mispredict_recovery_memory_type;
    type sq_num_elements_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of unsigned(SQ_TAG_BITS downto 0);
    signal sq_num_elements_mispredict_recovery_memory : sq_num_elements_mispredict_recovery_memory_type;
begin
    sq_enqueue <= '1' when uop_in_valid = '1' and uop_in.operation_type = OPTYPE_STORE and sq_full = '0' else '0';
    sq_dequeue <= '1' when store_queue(to_integer(sq_head_counter_reg)).retired = '1' and store_queue(to_integer(sq_head_counter_reg)).executed = '1' and sq_empty = '0' else '0';
    sq_dispatch <= '1' when store_queue(to_integer(sq_head_counter_reg)).retired = '1' and 
                            store_queue(to_integer(sq_head_counter_reg)).executed = '0' and 
                            store_queue(to_integer(sq_head_counter_reg)).address_valid = '1' and
                            store_queue(to_integer(sq_head_counter_reg)).data_valid = '1' and
                            sq_empty = '0' else '0';
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                sq_num_elements <= to_unsigned(0, SQ_TAG_BITS + 1);
                sq_tail_counter_reg <= to_unsigned(0, SQ_TAG_BITS);
                sq_head_counter_reg <= to_unsigned(0, SQ_TAG_BITS);
            else
                if (cdb_in.cdb_branch.valid = '1' and cdb_in.cdb_branch.branch_mispredicted = '1') then
                    sq_tail_counter_reg <= sq_tail_mispredict_recovery_memory(branch_mask_to_int(cdb_in.cdb_branch.branch_mask));
                    sq_num_elements <= sq_num_elements_mispredict_recovery_memory(branch_mask_to_int(cdb_in.cdb_branch.branch_mask));
                elsif (sq_enqueue = '1') then
                    sq_tail_counter_reg <= sq_tail_counter_next;
                    sq_num_elements <= sq_num_elements + 1;
                end if;
                
                if (sq_dequeue = '1') then
                    sq_num_elements <= sq_num_elements - 1;
                    sq_head_counter_reg <= sq_head_counter_next;
                    
                    -- Snapshots of num elements still have to be reduced by 1 when a store is dequeued since they hold how many stores would be in the SQ
                    -- if we didn't fetch any instructions after the speculated branch
                    for i in 0 to BRANCHING_DEPTH - 1 loop  
                        sq_num_elements_mispredict_recovery_memory(i) <= sq_num_elements_mispredict_recovery_memory(i) - 1;
                    end loop;
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
            
            else
                if (sq_enqueue = '1') then
                    store_queue(to_integer(sq_tail_counter_reg)).address_valid <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).data_valid <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).is_cmo <= uop_in.operation_select(6);
                    store_queue(to_integer(sq_tail_counter_reg)).cmo_opcode <= uop_in.operation_select(4 downto 3);
                    store_queue(to_integer(sq_tail_counter_reg)).size <= uop_in.operation_select(1 downto 0);
                    store_queue(to_integer(sq_tail_counter_reg)).executed <= '0';
                    store_queue(to_integer(sq_tail_counter_reg)).retired <= '0';
                end if;
                
                if (uop_in_valid = '1' and uop_in.branch_mask /= BRANCH_MASK_ZERO) then
                    sq_tail_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= sq_tail_counter_reg;
                    sq_num_elements_mispredict_recovery_memory(branch_mask_to_int(uop_in.branch_mask)) <= sq_num_elements;
                end if;
                
                if (rob_head_in.retire = '1' and rob_head_in.operation_type = OPTYPE_STORE) then
                    store_queue(to_integer(unsigned(rob_head_in.sq_tag))).retired <= '1';
                end if;
            end if;
        end if;
    end process;
    
    sq_empty <= '1' when sq_num_elements = 0 else '0';
    sq_full <= '1' when sq_num_elements = SQ_ENTRIES else '0';

end Behavioral;
