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

-- Definitions of input ports, output ports, types and constants required to create and configure 
-- the unified scheduler for the processor

package pkg_sched is
    constant ENTRY_BITS : integer := OPERATION_TYPE_BITS + OPERATION_SELECT_BITS + 3 * PHYS_REGFILE_ADDR_BITS + OPERAND_BITS + STORE_QUEUE_TAG_BITS + LOAD_QUEUE_TAG_BITS + INSTR_TAG_BITS + 2 * BRANCHING_DEPTH + 3;
    constant ENTRY_TAG_BITS : integer := integer(ceil(log2(real(SCHEDULER_ENTRIES))));
    
    constant ENTRY_TAG_ZERO : std_logic_vector(ENTRY_TAG_BITS - 1 downto 0) := (others => '0');
    constant OUTPUT_PORT_COUNT : integer := 2;

    -- ================================================================================
    --                                TYPE DECLARATIONS 
    -- ================================================================================
    
    type sched_out_port_type is record
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_sel : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        store_queue_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0); 
        load_queue_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0); 
        phys_src_reg_1 : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_src_reg_2 : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);         
        phys_dest_reg : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        curr_branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        dependent_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        valid : std_logic;
    end record; 

    constant SCHED_OUT_PORT_DEFAULT : sched_out_port_type := ((others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              (others => '0'),
                                                              '0');
    
    -- Scheduler entry format [OP. TYPE | OP. SEL | OPERAND_1_TAG | OPERAND_1_TAG_V | OPERAND_2_TAG | OPERAND_2_TAG_V | DEST_PHYS_REG_TAG | STORE QUEUE TAG | LOAD QUEUE TAG | IMMEDIATE | INSTR. TAG | CURR. BRANCH MASK | DEP. BRANCH TAG | BUSY]
    type reservation_station_entries_type is array(SCHEDULER_ENTRIES - 1 downto 0) of std_logic_vector(ENTRY_BITS - 1 downto 0);
    type sched_optype_bits_type is array(1 downto 0) of std_logic_vector(SCHEDULER_ENTRIES - 1 downto 0);
    type sched_read_sel_type is array(1 downto 0) of std_logic_vector(ENTRY_TAG_BITS - 1 downto 0);
    -- ================================================================================
    -- ////////////////////////////////////////////////////////////////////////////////
    -- ================================================================================
    
    -- ================================================================================
    --                        OPERATION TYPE - PORT MAPPINGS
    -- ================================================================================
    constant PORT_0_OPTYPE : std_logic_vector(2 downto 0) := "000";
    constant PORT_1_OPTYPE : std_logic_vector(2 downto 0) := "001";
    -- ================================================================================
    -- ////////////////////////////////////////////////////////////////////////////////
    -- ================================================================================
end package;