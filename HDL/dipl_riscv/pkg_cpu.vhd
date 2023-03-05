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

package pkg_cpu is
    -- CPU Config Parameters
    constant CPU_DATA_WIDTH_BITS : integer := 32;
    constant CPU_ADDR_WIDTH_BITS : integer := 32;
    
    constant ARCH_REGFILE_ENTRIES : integer range 1 to 1024 := 32;
    constant ARCH_REGFILE_ADDR_BITS : integer := integer(ceil(log2(real(ARCH_REGFILE_ENTRIES))));
    
    constant PHYS_REGFILE_ENTRIES : integer range 1 to 1024 := 48;
    constant PHYS_REGFILE_ADDR_BITS : integer := integer(ceil(log2(real(PHYS_REGFILE_ENTRIES))));
    
    -- ========================= DEBUG =========================
    constant ENABLE_EXT_BUS_ILA : boolean := false;
    constant ENABLE_UART_ILA : boolean := false;
    constant ENABLE_ARCH_REGFILE_MONITORING : boolean := false;
    -- =========================================================
    
    -- ========================= CAN BE MODIFIED =========================
    constant SCHEDULER_ENTRIES : integer range 1 to 1023 := 8;
    constant REORDER_BUFFER_ENTRIES : integer := 16;
    constant SQ_ENTRIES : integer := 4;
    constant LQ_ENTRIES : integer := 4;
    constant DECODED_INSTR_QUEUE_ENTRIES : integer := 4;
    
    constant BRANCHING_DEPTH : integer := 4;            -- How many branches this CPU is capable of speculating against. For ex. 4 Means 4 cond. branch instructions before further fetching is halted
    constant BP_TYPE : string := "2BSP";              -- Selects a branch predictor type to implement. Options: STATIC, 2BSP (2-Bit Saturating Counters)
    constant BP_STATIC_PREDICTION : std_logic := '1';      -- Value of 1 configures the static predictor to always predict taken, 0 does the opposite
    constant BP_2BST_INIT_VAL : std_logic_vector(1 downto 0) := "00";  -- Initial value of 2-bit saturating counters
    constant BP_ENTRIES : integer := 16;                 -- MUST BE POWER OF 2!
    constant BTB_TAG_BITS : integer := 16;
    
    constant ICACHE_ASSOCIATIVITY : integer := 2;                   -- MUST BE POWER OF 2!
    constant ICACHE_INSTR_PER_CACHELINE : integer := 4;
    constant ICACHE_NUM_SETS : integer := 16;                     -- MUST BE POWER OF 2!
    --constant ICACHE_REPLACEMENT_POLICY : string := "FIFO";                -- In consideration
    
    constant DCACHE_ASSOCIATIVITY : integer := 2;                   -- MUST BE POWER OF 2!
    constant DCACHE_ENTRIES_PER_CACHELINE : integer := 4;
    constant DCACHE_NUM_SETS : integer := 16;                     -- MUST BE POWER OF 2!
    constant NONCACHEABLE_BASE_ADDR : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0) := X"FFFF0000";
    
    constant CSR_PERF_COUNTERS_EN : boolean := true;
    
    constant PERF_COUNTERS_EN : boolean := false;
    constant PERF_COUNTERS_WIDTH_BITS : integer := 32;
    -- ===================================================================
    
    constant DCACHE_CACHELINE_SIZE : integer := (CPU_ADDR_WIDTH_BITS - integer(ceil(log2(real(DCACHE_ENTRIES_PER_CACHELINE)))) - 
                                              integer(ceil(log2(real(DCACHE_NUM_SETS)))) - 2 + DCACHE_ENTRIES_PER_CACHELINE * 4 * 8);
    
    constant DCACHE_TAG_SIZE : integer := CPU_ADDR_WIDTH_BITS - integer(ceil(log2(real(DCACHE_ENTRIES_PER_CACHELINE)))) - integer(ceil(log2(real(DCACHE_NUM_SETS)))) - integer(ceil(log2(real(4))));
    
    constant CDB_PC_BITS : integer := 32;
    
    constant OPCODE_BITS : integer := 5;
    constant OPERATION_TYPE_BITS : integer := 3;
    constant OPERATION_SELECT_BITS : integer := 10;
    constant OPERAND_BITS : integer := CPU_DATA_WIDTH_BITS;
    constant STORE_QUEUE_TAG_BITS : integer := integer(ceil(log2(real(SQ_ENTRIES))));
    constant LOAD_QUEUE_TAG_BITS : integer := integer(ceil(log2(real(LQ_ENTRIES))));
    constant INSTR_TAG_BITS : integer := integer(ceil(log2(real(REORDER_BUFFER_ENTRIES))));
    
    -- Constants
    constant PC_VAL_INIT : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0) := (others => '0');
    constant INSTR_TAG_ZERO : std_logic_vector(INSTR_TAG_BITS - 1 downto 0) := (others => '0');
    constant REG_ADDR_ZERO : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0) := (others => '0');
    constant PHYS_REG_TAG_ZERO : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0) := (others => '0');
    constant ADDR_ZERO : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0) := (others => '0');
    constant DATA_ZERO : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0) := (others => '0');
    constant BRANCH_MASK_ZERO : std_logic_vector(BRANCHING_DEPTH - 1 downto 0) := (others => '0');
    constant SQ_TAG_ZERO : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0) := (others => '0');
    
    -- Debugging Configuration
    constant ENABLE_REGFILE_ILA : boolean := true;
    
    -- Logic Vector Constants
    constant CONST_4 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0) := X"00000004";
    
    -- CPU Data Types
    type debug_regfile_type is array(ARCH_REGFILE_ENTRIES - 1 downto 0) of std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    type debug_rat_type is array(ARCH_REGFILE_ENTRIES - 1 downto 0) of std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    
    type uop_instr_dec_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        csr : std_logic_vector(11 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        arch_src_reg_1_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_src_reg_2_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_dest_reg_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
    end record;
    
    type uop_decoded_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        csr : std_logic_vector(11 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        arch_src_reg_1_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_src_reg_2_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_dest_reg_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_outcome : std_logic;
    end record;
    
    type uop_exec_type is record
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        csr : std_logic_vector(11 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        phys_src_reg_1_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_src_reg_2_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_dest_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        stq_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        ldq_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    end record;
    
    type uop_full_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        operation_type : std_logic_vector(OPERATION_TYPE_BITS - 1 downto 0);
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        csr : std_logic_vector(11 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        
        arch_src_reg_1_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_src_reg_2_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        arch_dest_reg_addr : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0);
        
        phys_src_reg_1_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_src_reg_2_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_dest_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        stq_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        ldq_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_outcome : std_logic;
    end record;

    type eu_input_type is record
        operand_1 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        operand_2 : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        immediate : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        
        operation_select : std_logic_vector(OPERATION_SELECT_BITS - 1 downto 0);
        phys_src_reg_1_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_src_reg_2_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        phys_dest_reg_addr : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        stq_tag : std_logic_vector(STORE_QUEUE_TAG_BITS - 1 downto 0);
        ldq_tag : std_logic_vector(LOAD_QUEUE_TAG_BITS - 1 downto 0);
        
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        speculated_branches_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        branch_predicted_target_pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_predicted_outcome : std_logic;
    end record;
    
    type bp_in_type is record
        fetch_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);      
        put_addr : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);        
        put_outcome : std_logic;                                                                -- Outcome of the branch entry to be updated   
        put_en : std_logic; 
    end record;
    
    type bp_out_type is record
        predicted_outcome : std_logic;
    end record;
    
    -- OPTYPE Definitions
    constant OPTYPE_INTEGER : std_logic_vector(2 downto 0) := "000";
    constant OPTYPE_BRANCH : std_logic_vector(2 downto 0) := "001";
    constant OPTYPE_LOAD : std_logic_vector(2 downto 0) := "010";
    constant OPTYPE_STORE : std_logic_vector(2 downto 0) := "011";
    constant OPTYPE_SYSTEM : std_logic_vector(2 downto 0) := "100";
    
    -- OPCODE Definitions
    constant OPCODE_LUI : std_logic_vector(4 downto 0) := "01101";
    constant OPCODE_AUIPC : std_logic_vector(4 downto 0) := "00101";
    constant OPCODE_JAL : std_logic_vector(4 downto 0) := "11011";
    constant OPCODE_JALR : std_logic_vector(4 downto 0) := "11001";
    constant OPCODE_COND_BR : std_logic_vector(4 downto 0) := "11000";
    constant OPCODE_LOAD : std_logic_vector(4 downto 0) := "00000";
    constant OPCODE_STORE : std_logic_vector(4 downto 0) := "01000";
    constant OPCODE_ALU_REG_REG : std_logic_vector(4 downto 0) := "01100";
    constant OPCODE_ALU_REG_IMM : std_logic_vector(4 downto 0) := "00100";
    constant OPCODE_SYSTEM : std_logic_vector(4 downto 0) := "11100";
    
    -- Load-Store Unit Operation Definitions
    constant LSU_OP_LW : std_logic_vector(7 downto 0) := "00000000";
    constant LSU_OP_SW : std_logic_vector(7 downto 0) := "10000010";    
    
    -- Integer EU Operation Definitions
    constant ALU_OP_ADD : std_logic_vector(3 downto 0) := "0000";
    constant ALU_OP_SUB : std_logic_vector(3 downto 0) := "1000";
    constant ALU_OP_XOR : std_logic_vector(3 downto 0) := "0100";
    constant ALU_OP_EQ : std_logic_vector(3 downto 0) := "1100";
    constant ALU_OP_LESS : std_logic_vector(3 downto 0) := "0010";
    constant ALU_OP_LESSU : std_logic_vector(3 downto 0) := "1110";
    constant ALU_OP_OR : std_logic_vector(3 downto 0) := "0110";
    constant ALU_OP_AND : std_logic_vector(3 downto 0) := "0111";
    constant ALU_OP_SLL : std_logic_vector(3 downto 0) := "0001";
    constant ALU_OP_SRL : std_logic_vector(3 downto 0) := "0101";
    constant ALU_OP_SRA : std_logic_vector(3 downto 0) := "1101";
    
    -- Opcode Definitions
    constant REG_ALU_OP : std_logic_vector(6 downto 0) := "0110011";
    constant IMM_ALU_OP : std_logic_vector(6 downto 0) := "0010011";
    constant LUI : std_logic_vector(6 downto 0) := "0110111";
    constant AUIPC : std_logic_vector(6 downto 0) := "0010111";
    constant LOAD : std_logic_vector(6 downto 0) := "0000011";
    constant STORE : std_logic_vector(6 downto 0) := "0100011";
    constant JAL : std_logic_vector(6 downto 0) := "1101111";
    constant JALR : std_logic_vector(6 downto 0) := "1100111";
    constant BR_COND : std_logic_vector(6 downto 0) := "1100011";
    
    -- Program Flow Definitions
    constant PROG_FLOW_NORM : std_logic_vector(1 downto 0) := "00";
    constant PROG_FLOW_COND : std_logic_vector(1 downto 0) := "01";
    constant PROG_FLOW_JAL : std_logic_vector(1 downto 0) := "10";
    constant PROG_FLOW_JALR : std_logic_vector(1 downto 0) := "11";

    -- CDB Configuration
    
    type cdb_type is record
        pc_low_bits : std_logic_vector(CDB_PC_BITS - 1 downto 0);
        instr_tag : std_logic_vector(INSTR_TAG_BITS - 1 downto 0);
        phys_dest_reg : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
        data : std_logic_vector(OPERAND_BITS - 1 downto 0);
        target_addr : std_logic_vector(OPERAND_BITS - 1 downto 0);
        branch_mask : std_logic_vector(BRANCHING_DEPTH - 1 downto 0); 
        branch_taken : std_logic;
        branch_mispredicted : std_logic;
        is_jalr : std_logic;            -- JALR is special by the fact that it is the only instruction whose target PC cannot be determined immediately from the instruction itself, so in order to branch
                                        -- properly we need to know if cdb has the result of a JALR instruction to fill the PC with the correct value
        valid : std_logic;
    end record;
    
    constant CDB_OPEN_CONST : cdb_type := ((others => '0'),
                                            (others => '0'),
                                            (others => '0'),
                                            (others => '0'),
                                            (others => '0'),
                                            (others => '0'),
                                            '0',
                                            '0',
                                            '0',
                                            '0');
                                            
    constant UOP_ZERO : uop_decoded_type := ((others => '0'),
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
    
    function branch_mask_to_int(branch_mask : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0)) return integer;
    
    type f1_f2_pipeline_reg_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        valid : std_logic;
    end record;
    
    type f2_f3_pipeline_reg_type is record
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_pred_target : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_pred_outcome : std_logic;
        valid : std_logic;
    end record;
    
    type f3_d1_pipeline_reg_type is record
        instruction : std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
        pc : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_pred_target : std_logic_vector(CPU_ADDR_WIDTH_BITS - 1 downto 0);
        branch_pred_outcome : std_logic;
        valid : std_logic;
    end record; 
    
    constant F1_F2_PIPELINE_REG_INIT : f1_f2_pipeline_reg_type := ((others => '0'),
                                                                   '0');
                                                                   
    constant F2_F3_PIPELINE_REG_INIT : f2_f3_pipeline_reg_type := ((others => '0'),
                                                                   (others => '0'),
                                                                   '0',
                                                                   '0');
                                                             
    constant F3_D1_PIPELINE_REG_INIT : f3_d1_pipeline_reg_type := ((others => '0'),
                                                                   (others => '0'),
                                                                   (others => '0'),
                                                                   '0',
                                                                    '0');
end pkg_cpu;

package body pkg_cpu is
    -- ASSUMES ONE-HOT ENCODING!
    function branch_mask_to_int(branch_mask : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0)) return integer is
        variable temp : integer := 0;
    begin
        for i in 0 to BRANCHING_DEPTH - 1 loop
            if (branch_mask(i) = '1') then
                temp := i;
            end if;
        end loop;
        return temp;
    end function branch_mask_to_int;
end package body;







