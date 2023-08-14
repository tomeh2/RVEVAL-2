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
use WORK.PKG_SCHED.ALL;
use WORK.PKG_CPU.ALL;

-- Package for the execution engine

package pkg_ee is
    type execution_engine_pipeline_register_1_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        csr : std_logic_vector(11 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        arch_src_reg_1_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_src_reg_2_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_dest_reg_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);

        phys_dest_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        stq_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        ldq_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_outcome : std_logic;
      
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_2_0_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_2_1_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_2_2_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_3_0_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_3_1_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_3_2_type is record
        uop : uop_exec_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_4_0_type is record
        eu_input : eu_input_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_4_1_type is record
        eu_input : eu_input_type;
        valid : std_logic;
    end record;
    
    type execution_engine_pipeline_register_4_2_type is record
        eu_input : eu_input_type;
        valid : std_logic;
    end record;
    
    constant EE_PIPELINE_REG_2_0_RESET : execution_engine_pipeline_register_2_0_type := 
                                           ((others => (others => '0')),
                                           '0');
                                           
    constant EE_PIPELINE_REG_2_1_RESET : execution_engine_pipeline_register_2_1_type := 
                                           ((others => (others => '0')),
                                           '0');
                                           
    constant EE_PIPELINE_REG_2_2_RESET : execution_engine_pipeline_register_2_2_type := 
                                           ((others => (others => '0')),
                                           '0'); 
                                           
    constant EE_PIPELINE_REG_3_0_RESET : execution_engine_pipeline_register_3_0_type := 
                                           ((others => (others => '0')),
                                           '0');
                                           
    constant EE_PIPELINE_REG_3_1_RESET : execution_engine_pipeline_register_3_1_type := 
                                           ((others => (others => '0')),
                                           '0');
                                           
    constant EE_PIPELINE_REG_3_2_RESET : execution_engine_pipeline_register_3_2_type := 
                                           ((others => (others => '0')),
                                           '0');
                                           
    constant EE_PIPELINE_REG_4_0_RESET : execution_engine_pipeline_register_4_0_type := 
                                           (EU_INPUT_ZERO,
                                           '0');
                                           
    constant EE_PIPELINE_REG_4_1_RESET : execution_engine_pipeline_register_4_1_type := 
                                           (EU_INPUT_ZERO,
                                           '0');
                                           
    constant EE_PIPELINE_REG_4_2_RESET : execution_engine_pipeline_register_4_2_type := 
                                           (EU_INPUT_ZERO,
                                           '0');
end package;