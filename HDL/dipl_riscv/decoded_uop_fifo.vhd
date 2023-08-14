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

-- CHANGE BACK TO SYNCHRONOUS OPERATION!!!!!!!

entity decoded_uop_fifo is
    generic(
        DEPTH : integer
    );
    port(
        cdb : in cdb_type;
    
        uop_in : in uop_decoded_type;
        uop_out : out uop_decoded_type;
    
        rd_en : in std_logic;
        rd_ready : out std_logic;
        wr_en : in std_logic;
        
        full : out std_logic;
        empty : out std_logic;
    
        clk : in std_logic;
        reset : in std_logic
    );
end decoded_uop_fifo;

architecture rtl of decoded_uop_fifo is
    constant COUNTER_WIDTH : integer := integer(ceil(log2(real(DEPTH))));
    constant FIFO_ENTRY_WIDTH : integer := CPU_ADDR_WIDTH_BITS + 
                                            OPERATION_TYPE_BITS + 
                                            OPERATION_SELECT_BITS +
                                            CPU_DATA_WIDTH_BITS +
                                            3 * ARCH_REGFILE_ADDR_BITS +
                                            BRANCHING_DEPTH + 1 + 12;
                                            
    constant PC_START : integer := FIFO_ENTRY_WIDTH - 1;
    constant PC_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS;
    constant OPTYPE_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - 1;
    constant OPTYPE_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS;
    constant OPSEL_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - 1;
    constant OPSEL_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS;
    constant IMM_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - 1;
    constant IMM_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS;
    constant ARCH_SRC_REG_1_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 1;
    constant ARCH_SRC_REG_1_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - ARCH_REGFILE_ADDR_BITS;
    constant ARCH_SRC_REG_2_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - ARCH_REGFILE_ADDR_BITS - 1;
    constant ARCH_SRC_REG_2_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 2 * ARCH_REGFILE_ADDR_BITS;
    constant ARCH_DEST_REG_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 2 * ARCH_REGFILE_ADDR_BITS - 1;
    constant ARCH_DEST_REG_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 3 * ARCH_REGFILE_ADDR_BITS;                                            
    constant BRANCH_MASK_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 3 * ARCH_REGFILE_ADDR_BITS - 1;                                            
    constant BRANCH_MASK_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 3 * ARCH_REGFILE_ADDR_BITS - BRANCHING_DEPTH;                                            
    constant CSR_START : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 3 * ARCH_REGFILE_ADDR_BITS - BRANCHING_DEPTH - 2;                                            
    constant CSR_END : integer := FIFO_ENTRY_WIDTH - CPU_ADDR_WIDTH_BITS - OPERATION_TYPE_BITS - OPERATION_SELECT_BITS - CPU_DATA_WIDTH_BITS - 3 * ARCH_REGFILE_ADDR_BITS - BRANCHING_DEPTH - 13;                                            

    type fifo_type is array (DEPTH - 1 downto 0) of std_logic_vector(FIFO_ENTRY_WIDTH - 1 downto 0);
    signal fifo : fifo_type;
    
    type br_spec_masks_type is array(DEPTH - 1 downto 0) of std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
    signal br_spec_masks : br_spec_masks_type;
    
    signal head_counter_reg : unsigned(COUNTER_WIDTH - 1 downto 0);
    signal head_counter_next : unsigned(COUNTER_WIDTH - 1 downto 0);
    
    signal tail_counter_reg : unsigned(COUNTER_WIDTH - 1 downto 0);
    signal tail_counter_next : unsigned(COUNTER_WIDTH - 1 downto 0);
    
    signal fifo_next_read_addr : unsigned(COUNTER_WIDTH - 1 downto 0);
    
    signal fifo_out : std_logic_vector(FIFO_ENTRY_WIDTH - 1 downto 0);
    
    signal i_full : std_logic;
    
    signal i_almost_empty : std_logic;
    signal i_almost_empty_delayed : std_logic;
    
    signal i_empty : std_logic;
    signal i_empty_delayed : std_logic;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                head_counter_reg <= (others => '0');
                tail_counter_reg <= (others => '0');
            else
                if (cdb.cdb_branch.branch_mispredicted = '1' and cdb.cdb_branch.valid = '1') then
                    head_counter_reg <= (others => '0');
                    tail_counter_reg <= (others => '0');
                else
                    if (wr_en = '1' and i_full = '0') then
                        tail_counter_reg <= tail_counter_next;
                    end if;
                
                    if (rd_en = '1' and i_empty = '0') then
                        head_counter_reg <= head_counter_next;
                    end if;
                end if;
                
            end if;
        end if;
    end process;
    
    process(head_counter_reg, tail_counter_reg)
    begin
        if (head_counter_reg = DEPTH - 1) then
            head_counter_next <= (others => '0');
        else
            head_counter_next <= head_counter_reg + 1;
        end if;
        
        if (tail_counter_reg = DEPTH - 1) then
            tail_counter_next <= (others => '0');
        else
            tail_counter_next <= tail_counter_reg + 1;
        end if;
    end process;
    

    uop_out.pc <= fifo_out(PC_START downto PC_END);
    uop_out.operation_type <= fifo_out(OPTYPE_START downto OPTYPE_END);
    uop_out.operation_select <= fifo_out(OPSEL_START downto OPSEL_END);
    uop_out.immediate <= fifo_out(IMM_START downto IMM_END);
    uop_out.arch_src_reg_1_addr <= fifo_out(ARCH_SRC_REG_1_START downto ARCH_SRC_REG_1_END);
    uop_out.arch_src_reg_2_addr <= fifo_out(ARCH_SRC_REG_2_START downto ARCH_SRC_REG_2_END);
    uop_out.arch_dest_reg_addr <= fifo_out(ARCH_DEST_REG_START downto ARCH_DEST_REG_END);
    uop_out.branch_mask <= fifo_out(BRANCH_MASK_START downto BRANCH_MASK_END);
    uop_out.branch_predicted_outcome <= fifo_out(12);
    uop_out.csr <= fifo_out(11 downto 0);
    process(clk)
    begin
        if (rising_edge(clk)) then
            for i in 0 to DEPTH - 1 loop
                if (cdb.cdb_branch.valid = '1') then
                    br_spec_masks(i) <= br_spec_masks(i) and not cdb.cdb_branch.branch_mask;
                end if;
            end loop;

            fifo_out <= fifo(to_integer(fifo_next_read_addr));
            
            if (cdb.cdb_branch.valid = '1') then
                uop_out.speculated_branches_mask <= br_spec_masks(to_integer(fifo_next_read_addr)) and not cdb.cdb_branch.branch_mask;
            else
                uop_out.speculated_branches_mask <= br_spec_masks(to_integer(fifo_next_read_addr));
            end if;
            

            if (wr_en = '1' and i_full = '0') then
                fifo(to_integer(tail_counter_reg)) <= uop_in.pc &
                                                      uop_in.operation_type &
                                                      uop_in.operation_select &
                                                      uop_in.immediate &
                                                      uop_in.arch_src_reg_1_addr &
                                                      uop_in.arch_src_reg_2_addr &
                                                      uop_in.arch_dest_reg_addr &
                                                      uop_in.branch_mask &
                                                      uop_in.branch_predicted_outcome &
                                                      uop_in.csr;
            
                br_spec_masks(to_integer(tail_counter_reg)) <= uop_in.speculated_branches_mask when cdb.cdb_branch.valid = '0' else uop_in.speculated_branches_mask and not cdb.cdb_branch.branch_mask;
            end if;
        end if;
    end process;

    fifo_next_read_addr <= head_counter_next when rd_en = '1' and rd_ready = '1' else head_counter_reg;

    rd_ready <= not i_empty_delayed and not i_empty and not i_almost_empty_delayed;
    
    i_almost_empty <= '1' when head_counter_next = tail_counter_reg else '0'; 
    i_almost_empty_delayed <= i_almost_empty when rising_edge(clk);
    i_empty_delayed <= i_empty when rising_edge(clk);
    i_empty <= '1' when tail_counter_reg = head_counter_reg else '0';
    empty <= i_empty;
    i_full <= '1' when (tail_counter_next = head_counter_reg) and not (reset = '1') else '0';
    full <= i_full;

end rtl;














