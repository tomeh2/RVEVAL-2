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

package pkg_fu is

    -- =====================================================
    --                   EXECUTION UNIT 0      
    -- =====================================================
    type exec_unit_0_pipeline_reg_0_type is record
        pc_low_bits : std_logic_vector(CDB_PC_BITS - 1 downto 0);
        result : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        target_addr : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        phys_dest_reg : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_mispredicted : std_logic;
        branch_taken : std_logic;
        is_jalr : std_logic;
        valid : std_logic;
    end record;
 
    constant EU_0_PIPELINE_REG_0_INIT : exec_unit_0_pipeline_reg_0_type := ((others => '0'),
                                                                      (others => '0'),
                                                                      (others => '0'),
                                                                      (others => '0'),
                                                                      (others => '0'),
                                                                      (others => '0'),
                                                                      (others => '0'),
                                                                      '0',
                                                                      '0',
                                                                      '0',
                                                                      '0');
    
    -- =====================================================
    --              LOAD - STORE UNIT REGISTERS             
    -- =====================================================
    type exec_unit_1_pipeline_reg_0_type is record
        generated_address : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        generated_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        generated_data_tag : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        generated_data_valid : std_logic;
        ldq_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        ldq_tag_valid : std_logic;
        stq_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        stq_tag_valid : std_logic;
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        valid : std_logic;
    end record;
    
    constant EU_1_PIPELINE_REG_0_INIT : exec_unit_1_pipeline_reg_0_type := ((others => '0'),
                                                                            (others => '0'),
                                                                            (others => '0'),
                                                                            '0',
                                                                            (others => '0'),
                                                                            '0',
                                                                            (others => '0'),
                                                                            '0',
                                                                            (others => '0'),
                                                                            '0');
end package;