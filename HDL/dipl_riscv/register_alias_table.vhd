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

-- Potentially change it to a synchronous read

entity register_alias_table is
    generic(
        PHYS_REGFILE_ENTRIES : integer range 1 to 1024;
        ARCH_REGFILE_ENTRIES : integer range 1 to 1024;
        
        ZERO_CYCLE_DELAY : boolean;
        VALID_BIT_INIT_VAL : std_logic;
        ENABLE_VALID_BITS : boolean
    );
    port(
        -- ========== DEBUG ==========
        debug_rat : out debug_rat_type;
        -- ===========================
        
        cdb : in cdb_type;
        -- ========== READING PORTS ==========
        -- Inputs take the architectural register address for which we want the physical entry address
        arch_reg_addr_read_1 : in std_logic_vector(integer(ceil(log2(real(ARCH_REGFILE_ENTRIES)))) - 1 downto 0);
        arch_reg_addr_read_2 : in std_logic_vector(integer(ceil(log2(real(ARCH_REGFILE_ENTRIES)))) - 1 downto 0);
        read_en : in std_logic;
        
        -- Outputs give the physical entry address
        phys_reg_addr_read_1 : out std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
        phys_reg_addr_read_2 : out std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
        -- ===================================
        
        -- ========== WRITING PORTS ==========        
        arch_reg_addr_write_1 : in std_logic_vector(integer(ceil(log2(real(ARCH_REGFILE_ENTRIES)))) - 1 downto 0); 
        phys_reg_addr_write_1 : in std_logic_vector(integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))) - 1 downto 0);
        write_en : in std_logic;
        -- ===================================
              
        -- ========== SPECULATION ==========
        next_instr_branch_mask : in std_logic_vector(BRANCHING_DEPTH - 1 downto 0);
        next_uop_valid : in std_logic;
        -- =================================
                
        -- Control signals
        
        clk : in std_logic;
        reset : in std_logic
    );
end register_alias_table;

architecture rtl of register_alias_table is
    constant PHYS_REGFILE_ADDR_BITS : integer := integer(ceil(log2(real(PHYS_REGFILE_ENTRIES)))); 
    constant ARCH_REGFILE_ADDR_BITS : integer := integer(ceil(log2(real(ARCH_REGFILE_ENTRIES)))); 

    constant ARCH_REGFILE_ADDR_ZERO : std_logic_vector(ARCH_REGFILE_ADDR_BITS - 1 downto 0) := (others => '0');
    constant PHYS_REGFILE_ADDR_ZERO : std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0) := (others => '0');

    type rat_type is array (ARCH_REGFILE_ENTRIES - 1 downto 0) of std_logic_vector(PHYS_REGFILE_ADDR_BITS - 1 downto 0);
    constant RAT_TYPE_ZERO : rat_type := (others => (others => '0'));
    
    type rat_mispredict_recovery_memory_type is array (BRANCHING_DEPTH - 1 downto 0) of rat_type;

    signal rat : rat_type;
    signal rat_mispredict_recovery_memory : rat_mispredict_recovery_memory_type;
begin
    rat_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                for i in 0 to ARCH_REGFILE_ENTRIES - 1 loop
                    rat(i) <= std_logic_vector(to_unsigned(i, PHYS_REGFILE_ADDR_BITS));
                end loop;
                
                for i in 0 to BRANCHING_DEPTH - 1 loop
                    rat_mispredict_recovery_memory(i) <= RAT_TYPE_ZERO;
                end loop;
            else
                
            
                if (write_en = '1' and arch_reg_addr_write_1 /= ARCH_REGFILE_ADDR_ZERO) then
                    rat(to_integer(unsigned(arch_reg_addr_write_1))) <= phys_reg_addr_write_1;
                end if;
                
                -- Speculation
                if (cdb.cdb_branch.branch_mispredicted = '1' and cdb.cdb_branch.valid = '1') then
                    rat <= rat_mispredict_recovery_memory(branch_mask_to_int(cdb.cdb_branch.branch_mask));
                elsif (next_instr_branch_mask /= BRANCH_MASK_ZERO and next_uop_valid = '1') then
                    rat_mispredict_recovery_memory(branch_mask_to_int(next_instr_branch_mask)) <= rat;
                    rat_mispredict_recovery_memory(branch_mask_to_int(next_instr_branch_mask))(to_integer(unsigned(arch_reg_addr_write_1))) <= phys_reg_addr_write_1;
                end if;
            end if;
        end if;
    end process;
    
    gen_zcd : if (ZERO_CYCLE_DELAY = true) generate
        process(all)
        begin
            phys_reg_addr_read_1 <= rat(to_integer(unsigned(arch_reg_addr_read_1)));
            phys_reg_addr_read_2 <= rat(to_integer(unsigned(arch_reg_addr_read_2)));    
        end process;
    else generate
        process(clk)
        begin
            if (rising_edge(clk)) then
                if (read_en = '1') then
                    phys_reg_addr_read_1 <= rat(to_integer(unsigned(arch_reg_addr_read_1)));
                    phys_reg_addr_read_2 <= rat(to_integer(unsigned(arch_reg_addr_read_2)));
                end if;
            end if;
        end process;
    end generate;
    
    rat_debug_gen : if (ENABLE_ARCH_REGFILE_MONITORING = true) generate
        process(all)
        begin
            for i in 0 to ARCH_REGFILE_ENTRIES - 1 loop
                debug_rat(i) <= rat(i);
            end loop;
        end process;
    end generate;
end rtl;
