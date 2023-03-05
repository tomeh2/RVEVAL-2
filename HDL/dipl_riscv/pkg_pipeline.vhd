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

use work.pkg_cpu.all;

package pkg_pipeline is
    type pipeline_regs_en_type is record
        fet_de_reg_en : std_logic;
        de_ex_reg_en : std_logic;
        ex_mem_reg_en : std_logic;
        mem_wb_reg_en : std_logic;
    end record;
    
    type pipeline_regs_rst_type is record
        fet_de_reg_rst : std_logic;
        de_ex_reg_rst : std_logic;
        ex_mem_reg_rst : std_logic;
        mem_wb_reg_rst : std_logic;
    end record;
    
    type pipeline_fwd_cntrl_type is record
        reg_1_fwd_em : std_logic;
        reg_1_fwd_mw : std_logic;
        reg_2_fwd_em : std_logic;
        reg_2_fwd_mw : std_logic;
    end record;

    type fet_de_register_type is record
        -- ===== CONTROL (DECODE) =====
        instruction : std_logic_vector(31 downto 0);
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
    end record;

    type de_ex_register_type is record
        -- ===== DATA =====
        reg_1_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        reg_2_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        immediate_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        -- ===== CONTROL (REGISTER FILE) =====
        reg_1_addr : std_logic_vector(3 + ENABLE_BIG_REGFILE downto 0);
        reg_2_addr : std_logic_vector(3 + ENABLE_BIG_REGFILE downto 0);
        reg_1_used : std_logic;
        reg_2_used : std_logic;
        
        -- ===== CONTROL (EXECUTE) =====
        alu_op_sel : std_logic_vector(3 downto 0);
        immediate_used : std_logic;
        pc_used : std_logic;
        
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        prog_flow_cntrl : std_logic_vector(1 downto 0);
        invert_condition : std_logic;
        
        -- ===== CONTROL (MEMORY) =====
        transfer_data_type : std_logic_vector(2 downto 0);
        
        execute_read : std_logic;
        execute_write : std_logic;
        
        -- ===== CONTROL (WRITEBACK) =====
        reg_wr_addr : std_logic_vector(3 + ENABLE_BIG_REGFILE downto 0);
        reg_wr_en : std_logic;
    end record;
    
    
    type ex_mem_register_type is record
        -- ===== DATA =====
        alu_result : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        reg_2_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        -- ===== CONTROL (MEMORY) =====
        transfer_data_type : std_logic_vector(2 downto 0);
        
        execute_read : std_logic;
        execute_write : std_logic;
        
        -- ===== CONTROL (WRITEBACK) =====
        reg_wr_addr : std_logic_vector(3 + ENABLE_BIG_REGFILE downto 0);
        reg_wr_en : std_logic;
    end record;
    
    type mem_wb_register_type is record
        -- ===== DATA =====
        mem_data : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        -- ===== CONTROL (WRITEBACK) =====
        reg_wr_addr : std_logic_vector(3 + ENABLE_BIG_REGFILE downto 0);
        reg_wr_en : std_logic;
    end record;
    
    constant FET_DE_REGISTER_CLEAR : fet_de_register_type := (instruction => (others => '0'),
                                                              pc => (others => '0'));
    
    constant DE_EX_REGISTER_CLEAR : de_ex_register_type := (reg_1_data => (others => '0'),
                                                            reg_2_data => (others => '0'),
                                                            immediate_data => (others => '0'),
                                                            reg_1_addr => (others => '0'),
                                                            reg_2_addr => (others => '0'),
                                                            reg_1_used => '0',
                                                            reg_2_used => '0',
                                                            alu_op_sel => (others => '0'),
                                                            immediate_used => '0',
                                                            pc_used => '0',
                                                            reg_wr_addr => (others => '0'),
                                                            reg_wr_en => '0',
                                                            prog_flow_cntrl => (others => '0'),
                                                            invert_condition => '0',
                                                            transfer_data_type => "000",
                                                            execute_read => '0',
                                                            execute_write => '0',
                                                            pc => (others => '0'));
                                                            
    constant EX_MEM_REGISTER_CLEAR : ex_mem_register_type := (alu_result => (others => '0'),
                                                              reg_2_data => (others => '0'),
                                                              reg_wr_addr => (others => '0'),
                                                              reg_wr_en => '0',
                                                              transfer_data_type => "000",
                                                              execute_read => '0',
                                                              execute_write => '0');
                                                              
    constant MEM_WB_REGISTER_CLEAR : mem_wb_register_type := (mem_data => (others => '0'),
                                                              reg_wr_addr => (others => '0'),
                                                              reg_wr_en => '0');                                                              
end pkg_pipeline;