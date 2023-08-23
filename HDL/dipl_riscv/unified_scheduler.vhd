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
use WORK.PKG_SCHED.ALL;
use WORK.PKG_CPU.ALL;

-- ================ NOTES ================ 
-- Possible optimization (?): Do reads on falling edge and writes on rising edge (or vise versa)
-- =======================================

entity unified_scheduler is
    port(
        -- COMMON DATA BUS
        cdb : in cdb_type;
    
        -- INPUTS
        uop_in_0 : in uop_exec_type;
        uop_in_0_valid : in std_logic;
        operand_1_valid : in std_logic;
        operand_2_valid : in std_logic;
        
        -- OUTPUTS
        uop_out_0 : out uop_exec_type;
        uop_out_0_valid : out std_logic;
        uop_out_1 : out uop_exec_type;
        uop_out_1_valid : out std_logic;
        uop_out_2 : out uop_exec_type;
        uop_out_2_valid : out std_logic;

        -- CONTROL
        dispatch_en : in std_logic_vector(OUTPUT_PORT_COUNT - 1 downto 0);
        full : out std_logic;
        empty : out std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end unified_scheduler;

architecture rtl of unified_scheduler is
    type sched_entry_type is record
        uop : uop_exec_type;
        operand_1_ready : std_logic;
        operand_2_ready : std_logic;
        valid : std_logic;
    end record;

    
    type sched_entries_type is array (SCHEDULER_ENTRIES - 1 downto 0) of sched_entry_type;
    signal sched_entries : sched_entries_type;
    
    type sched_dispatch_ready_bits_type is array(OUTPUT_PORT_COUNT - 1 downto 0) of std_logic_vector(SCHEDULER_ENTRIES - 1 downto 0);
    signal sched_dispatch_ready_bits : sched_dispatch_ready_bits_type;

    signal sched_operands_ready_bits : std_logic_vector(SCHEDULER_ENTRIES - 1 downto 0);
    signal sched_busy_bits : std_logic_vector(SCHEDULER_ENTRIES - 1 downto 0);
    signal sched_optype_bits : sched_optype_bits_type;
    
    signal sched_read_sel : sched_read_sel_type;
    
    signal sched_sel_write_1 : std_logic_vector(ENTRY_TAG_BITS - 1 downto 0);

    signal sched_read_sel_valid : std_logic_vector(OUTPUT_PORT_COUNT - 1 downto 0);

    signal sched_operand_1_ready : std_logic;
    signal sched_operand_2_ready : std_logic;
begin
    sched_empty_full_proc : process(sched_entries)
        variable temp_f : std_logic;
        variable temp_e : std_logic;
    begin
        temp_f := '1';
        temp_e := '1';
        for i in 0 to SCHEDULER_ENTRIES - 1 loop
            temp_f := temp_f and sched_entries(i).valid;
            temp_e := temp_e and not sched_entries(i).valid;
        end loop;
        full <= temp_f;
        empty <= temp_e;
    end process;

    -- Generates a vector containing all busy bits of the reservation station
    sched_busy_bits_proc : process(sched_entries)
    begin
        for i in 0 to SCHEDULER_ENTRIES - 1 loop
            sched_busy_bits(i) <= not sched_entries(i).valid;
        end loop;
    end process;
    
    -- Generates a vector of ready bits for the reservation station. Ready bits indicate to the allocators that the reservation station entry
    -- is ready to be dispatched. That means that the entry has all operands (both entry tags are 0), is busy and has not yet been dispatched
    sched_operands_ready_bits_proc : process(sched_entries)
    begin
        for i in 0 to SCHEDULER_ENTRIES - 1 loop
            if (sched_entries(i).operand_1_ready = '1' and
                sched_entries(i).operand_2_ready = '1' and
                sched_entries(i).valid = '1') then
                sched_operands_ready_bits(i) <= '1';
            else
                sched_operands_ready_bits(i) <= '0';
            end if;
        end loop;
    end process;
    
    -- Generates a vector of bits which indicate that the corresponding scheduler entry is ready to dispatch to its corresponding port
    sched_optype_bits_proc : process(sched_entries, sched_operands_ready_bits)
    begin
        for i in 0 to SCHEDULER_ENTRIES - 1 loop
            if ((sched_entries(i).uop.operation_type = OPTYPE_INTEGER or sched_entries(i).uop.operation_type = OPTYPE_SYSTEM)) then
                sched_dispatch_ready_bits(0)(i) <= sched_operands_ready_bits(i);
            else
                sched_dispatch_ready_bits(0)(i) <= '0';
            end if;
            
            if ((sched_entries(i).uop.operation_type = OPTYPE_LOAD or sched_entries(i).uop.operation_type = OPTYPE_STORE)) then
                sched_dispatch_ready_bits(1)(i) <= sched_operands_ready_bits(i);
            else
                sched_dispatch_ready_bits(1)(i) <= '0';
            end if;
            
            if (sched_entries(i).uop.operation_type = OPTYPE_BRANCH) then
                sched_dispatch_ready_bits(2)(i) <= sched_operands_ready_bits(i);
            else
                sched_dispatch_ready_bits(2)(i) <= '0';
            end if;
            
            
        end loop;
    end process;

    -- Priority encoder that takes busy bits as its input and selects one free entry to be written into 
    prio_enc_write_1 : entity work.priority_encoder(rtl)
                       generic map(NUM_INPUTS => SCHEDULER_ENTRIES,
                                   HIGHER_INPUT_HIGHER_PRIO => false)
                       port map(d => sched_busy_bits,
                                q => sched_sel_write_1);
     
    
     
    -- Generates priority encoders used to select an entry that is ready to dispatch to the corresponding port
    prio_enc_read_sel_gen : for i in 0 to OUTPUT_PORT_COUNT - 1 generate
        prio_enc_read_sel : entity work.priority_encoder(rtl)
                            generic map(NUM_INPUTS => SCHEDULER_ENTRIES,
                                        HIGHER_INPUT_HIGHER_PRIO => false)
                            port map(d => sched_dispatch_ready_bits(i),
                                     q => sched_read_sel(i),
                                     valid => sched_read_sel_valid(i));
    end generate;

    -- This is a check for whether current instruction's required tags are being broadcast on the CDB right now. If they are then that will immediately be taken
    -- into consideration. Without this part the instruction in an entry could keep waiting for a result of an instruction that has already finished execution.  
    reservation_station_operand_select_proc : process(cdb, uop_in_0, operand_1_valid, operand_2_valid)
    begin
        if ((uop_in_0.phys_src_reg_1_addr = cdb.cdb_branch.phys_dest_reg and cdb.cdb_branch.valid = '1') or
            (uop_in_0.phys_src_reg_1_addr = cdb.cdb_data.phys_dest_reg and cdb.cdb_data.valid = '1')) then
            sched_operand_1_ready <= '1';
        else
            sched_operand_1_ready <= operand_1_valid;
        end if;
        
        if ((uop_in_0.phys_src_reg_2_addr = cdb.cdb_branch.phys_dest_reg and cdb.cdb_branch.valid = '1') or 
            (uop_in_0.phys_src_reg_2_addr = cdb.cdb_data.phys_dest_reg and cdb.cdb_data.valid = '1')) then
            sched_operand_2_ready <= '1'; 
        else
            sched_operand_2_ready <= operand_2_valid;
        end if;
    end process;
                               
    -- Controls writing into an entry of the reservation station. Appropriately sets 'dispatched' and 'busy' bits by listening to the CDB.
    reservation_station_write_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to SCHEDULER_ENTRIES - 1 loop
                    sched_entries(i).valid <= '0';
                end loop;
            else
                if (uop_in_0_valid = '1' and full = '0') then
                    sched_entries(to_integer(unsigned(sched_sel_write_1))).uop <= uop_in_0;
                    sched_entries(to_integer(unsigned(sched_sel_write_1))).uop.speculated_branches_mask <= uop_in_0.speculated_branches_mask when cdb.cdb_branch.valid = '0' else uop_in_0.speculated_branches_mask and not cdb.cdb_branch.branch_mask;
                    sched_entries(to_integer(unsigned(sched_sel_write_1))).operand_1_ready <= sched_operand_1_ready;
                    sched_entries(to_integer(unsigned(sched_sel_write_1))).operand_2_ready <= sched_operand_2_ready;
                    sched_entries(to_integer(unsigned(sched_sel_write_1))).valid <= '1';
                end if;

                for i in 0 to OUTPUT_PORT_COUNT - 1 loop
                    if (dispatch_en(i) = '1' and sched_read_sel_valid(i) = '1') then
                        sched_entries(to_integer(unsigned(sched_read_sel(i)))).valid <= '0';
                    end if;
                end loop;

                for i in 0 to SCHEDULER_ENTRIES - 1 loop
                    if ((sched_entries(i).uop.phys_src_reg_1_addr = cdb.cdb_branch.phys_dest_reg and
                        sched_entries(i).valid = '1' and cdb.cdb_branch.valid = '1') or 
                        (sched_entries(i).uop.phys_src_reg_1_addr = cdb.cdb_data.phys_dest_reg and
                        sched_entries(i).valid = '1' and cdb.cdb_data.valid = '1')) then
                        sched_entries(i).operand_1_ready <= '1';
                    end if;
                    
                    if ((sched_entries(i).uop.phys_src_reg_2_addr = cdb.cdb_branch.phys_dest_reg and
                        sched_entries(i).valid = '1' and cdb.cdb_branch.valid = '1') or 
                        (sched_entries(i).uop.phys_src_reg_2_addr = cdb.cdb_data.phys_dest_reg and
                        sched_entries(i).valid = '1' and cdb.cdb_data.valid = '1')) then
                        sched_entries(i).operand_2_ready <= '1';
                    end if;
                    
                    -- Cancel all speculative instructions for which it has been determined that they have been mispredicted
                    if ((sched_entries(i).uop.speculated_branches_mask and cdb.cdb_branch.branch_mask) /= BRANCH_MASK_ZERO and cdb.cdb_branch.branch_mispredicted = '1' and cdb.cdb_branch.valid = '1') then
                        sched_entries(i).valid <= '0';
                    elsif (cdb.cdb_branch.branch_mask /= BRANCH_MASK_ZERO and cdb.cdb_branch.valid = '1' and sched_entries(i).valid = '1') then
                        sched_entries(i).uop.speculated_branches_mask <= sched_entries(i).uop.speculated_branches_mask and (not cdb.cdb_branch.branch_mask);
                    end if;
                end loop;
            end if;
        end if;
    end process;
    
    -- Puts the selected entry onto one exit port of the reservation station
    reservation_station_dispatch_proc : process(sched_entries, sched_read_sel, dispatch_en, sched_read_sel_valid)
    begin
        uop_out_0 <= sched_entries(to_integer(unsigned(sched_read_sel(0)))).uop;
        uop_out_0_valid <= dispatch_en(0) and sched_read_sel_valid(0);
        
        uop_out_1 <= sched_entries(to_integer(unsigned(sched_read_sel(1)))).uop;
        uop_out_1_valid <= dispatch_en(1) and sched_read_sel_valid(1);
        
        uop_out_2 <= sched_entries(to_integer(unsigned(sched_read_sel(2)))).uop;
        uop_out_2_valid <= dispatch_en(2) and sched_read_sel_valid(2);
    end process;
end rtl;












