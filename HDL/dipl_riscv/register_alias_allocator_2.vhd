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

entity register_alias_allocator_2 is
    generic(
        PHYS_REGFILE_ENTRIES : integer range 1 to 1024;
        ARCH_REGFILE_ENTRIES : integer range 1 to 1024
    );
    port(
        cdb : in cdb_type;
        curr_instr_branch_mask : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0); 
        next_uop_valid : in std_logic;
        
        free_reg_alias : in std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
        alloc_reg_alias : out std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
        
        put_en : in std_logic;
        get_en : in std_logic;
        
        empty : out std_logic;
        clk : in std_logic;
        reset : in std_logic
    );
end register_alias_allocator_2;

architecture rtl of register_alias_allocator_2 is
    type register_status_vector_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of std_logic_vector(PHYS_REGFILE_ENTRIES - 1 downto 0);
    signal rsv_mispredict_recovery_memory : register_status_vector_mispredict_recovery_memory_type;
    
    signal n_empty : std_logic;

    signal i_alloc_reg_alias : std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
    signal register_status_vector : std_logic_vector(PHYS_REGFILE_ENTRIES - 1 downto 0);
begin
    --assert PHYS_REGFILE_ENTRIES <= ARCH_REGFILE_ENTRIES report "PHYS regfile smaller then ARCH regfile!" severity error;

    reg_select_prio_enc : entity work.priority_encoder(rtl)
           generic map(NUM_INPUTS => PHYS_REGFILE_ENTRIES,
                       HIGHER_INPUT_HIGHER_PRIO => false)
           port map(d => register_status_vector,
                    q => i_alloc_reg_alias,
                    valid => n_empty);
           
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                reg_status_vector_rst : for i in 0 to PHYS_REGFILE_ENTRIES - 1 loop
                    if (i < ARCH_REGFILE_ENTRIES) then
                        register_status_vector(i) <= '0';
                    else
                        register_status_vector(i) <= '1';
                    end if;
                end loop;
            else
                if (cdb.branch_mispredicted = '1' and cdb.valid = '1') then
                    register_status_vector <= rsv_mispredict_recovery_memory(branch_mask_to_int(cdb.branch_mask));
                    
                    if (cdb.is_jalr = '1') then
                        register_status_vector(to_integer(unsigned(cdb.phys_dest_reg))) <= '0';
                    end if;
                else
                    if (curr_instr_branch_mask /= BRANCH_MASK_ZERO and next_uop_valid = '1') then
                        rsv_mispredict_recovery_memory(branch_mask_to_int(curr_instr_branch_mask)) <= register_status_vector;
                    end if;
                
                    if (n_empty = '1' and get_en = '1') then
                        register_status_vector(to_integer(unsigned(i_alloc_reg_alias))) <= '0';
                    end if;
                    
                    if (put_en = '1') then
                        -- Register aliases can ONLY be cleared in mispredict recovery memories. This is to prevent the recovered table from having registers marked as allocated
                        -- because the snapshot was taken before the register was deallocated
                        for i in 0 to BRANCHING_DEPTH - 1 loop
                            rsv_mispredict_recovery_memory(i)(to_integer(unsigned(free_reg_alias))) <= '1';
                        end loop;

                        if (free_reg_alias /= PHYS_REG_TAG_ZERO) then
                            register_status_vector(to_integer(unsigned(free_reg_alias))) <= '1';
                        end if;
                    end if;
                end if;
                
            end if;
        end if;
    end process;

    alloc_reg_alias <= i_alloc_reg_alias when get_en = '1' else (others => '0');
    empty <= not n_empty;

end rtl;
