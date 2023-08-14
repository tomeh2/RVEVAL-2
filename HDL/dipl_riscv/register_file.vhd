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

--------------------------------
-- NOTES:
-- 1) Does this infer LUT-RAM?
--------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

use work.pkg_cpu.all;

entity register_file is
    generic(
        REG_DATA_WIDTH_BITS : integer;                                                        -- Number of bits in the registers (XLEN)
        REGFILE_ENTRIES : integer                                                                -- Number of registers in the register file (2 ** REGFILE_SIZE)
    );
    port(
        debug_rat : in debug_rat_type;
        
        cdb : in cdb_type;
        
        -- Address busses
        rd_1_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        rd_2_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        rd_3_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        rd_4_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        wr_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        
        
        alloc_reg_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        alloc_reg_addr_v : in std_logic;
        
        reg_1_valid_bit_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        reg_2_valid_bit_addr : in std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0);
        reg_1_valid : out std_logic;
        reg_2_valid : out std_logic;
        -- Data busses
        rd_1_data : out std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
        rd_2_data : out std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
        rd_3_data : out std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
        rd_4_data : out std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
        wr_data : in std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
        
        -- Control busses
    
        en : in std_logic;
        rd_1_en : in std_logic;
        rd_2_en : in std_logic;
        reset : in std_logic;                                                           -- Sets all registers to 0 when high (synchronous)
        clk : in std_logic                                                         
    );
end register_file;

architecture rtl of register_file is
    -- ============ DEBUG ============
    type reg_file_debug_type is array (ARCH_REGFILE_ENTRIES - 1 downto 0) of std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
    signal reg_file_debug : reg_file_debug_type;
    -- ===============================

    -- ========== CONSTANTS ==========
    constant REG_ADDR_ZERO : std_logic_vector(integer(ceil(log2(real(REGFILE_ENTRIES)))) - 1 downto 0) := (others => '0'); 
    -- ===============================

    -- ========== RF REGISTERS ==========
    type reg_file_type is array (REGFILE_ENTRIES - 1 downto 0) of std_logic_vector(REG_DATA_WIDTH_BITS - 1 downto 0);
    signal reg_file : reg_file_type := (others => (others => '0'));
    
    signal reg_file_valid_bits : std_logic_vector(REGFILE_ENTRIES - 1 downto 0);
    -- ==================================
    
    signal rf_write_en : std_logic;
begin
    

    rf_memory_proc : process(clk)
    begin
        -- Writing to registers
        if (rising_edge(clk)) then
            if (rf_write_en = '1') then                    
                reg_file(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
                
            if (rd_1_en = '1') then
                rd_1_data <= reg_file(to_integer(unsigned(rd_1_addr)));
                rd_2_data <= reg_file(to_integer(unsigned(rd_2_addr)));
            end if;
            
            if (rd_2_en = '1') then
                rd_3_data <= reg_file(to_integer(unsigned(rd_3_addr)));
                rd_4_data <= reg_file(to_integer(unsigned(rd_4_addr)));
            end if;

        end if;
    end process;

    rf_valid_bits_proc : process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                reg_file_valid_bits <= (others => '1');
            else
                if (rf_write_en = '1') then
                    reg_file_valid_bits(to_integer(unsigned(wr_addr))) <= '1';
                end if;
            
                if (alloc_reg_addr_v = '1' and alloc_reg_addr /= PHYS_REG_TAG_ZERO) then
                    reg_file_valid_bits(to_integer(unsigned(alloc_reg_addr))) <= '0';
                end if; 
            end if;
        end if;
    end process;
    
    process(all)
    begin
        if ((cdb.phys_dest_reg = reg_1_valid_bit_addr) and cdb.valid = '1') then
            reg_1_valid <= '1';
       --elsif (reg_1_valid_bit_addr = alloc_reg_addr and alloc_reg_addr_v = '1' and alloc_reg_addr /= PHYS_REG_TAG_ZERO) then
        --   reg_1_valid <= '0';
        else
            reg_1_valid <= reg_file_valid_bits(to_integer(unsigned(reg_1_valid_bit_addr)));
        end if;
                
        if ((cdb.phys_dest_reg = reg_2_valid_bit_addr) and cdb.valid = '1') then
            reg_2_valid <= '1';
        --elsif (reg_2_valid_bit_addr = alloc_reg_addr and alloc_reg_addr_v = '1' and alloc_reg_addr /= PHYS_REG_TAG_ZERO) then
        --    reg_2_valid <= '0';
        else
             reg_2_valid <= reg_file_valid_bits(to_integer(unsigned(reg_2_valid_bit_addr)));
        end if;
    end process;
    
    rf_write_en <= '1' when en = '1' and wr_addr /= REG_ADDR_ZERO else '0';
    
    regfile_debug_gen : if (ENABLE_ARCH_REGFILE_MONITORING = true) generate
        process(all)
        begin
            for i in 0 to ARCH_REGFILE_ENTRIES - 1 loop
                reg_file_debug(i) <= reg_file(to_integer(unsigned(debug_rat(i))));
            end loop;
        end process;
    end generate;
end rtl;
