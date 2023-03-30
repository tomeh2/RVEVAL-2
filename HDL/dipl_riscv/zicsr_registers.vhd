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
use WORK.PKG_CPU.ALL;

entity zicsr_registers is
    port(
        read_addr : in std_logic_vector(11 downto 0);
        read_data : out std_logic_vector(CPU_DATA_WIDTH_BITS - 1 downto 0);
    
        perfcntr_br_commit : in std_logic;
        perfcntr_br_mispred_cdb : in std_logic;
        perfcntr_br_mispred_fe : in std_logic;
        perfcntr_bc_empty : in std_logic;
        
        perfcntr_icache_stall : in std_logic;
        
        dcache_access : in std_logic;
        dcache_miss : in std_logic;
        
        perfcntr_issue_stall_cycles : in std_logic;
        perfcntr_fifo_full : in std_logic;
        perfcntr_raa_empty : in std_logic;
        perfcntr_rob_full : in std_logic;
        perfcntr_sched_full : in std_logic;
        perfcntr_lq_full : in std_logic;
        perfcntr_sq_full : in std_logic;
        
        instr_ret : in std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end zicsr_registers;

architecture rtl of zicsr_registers is
    constant CSR_CYCLES : integer := 0;
    constant CSR_INSTRET : integer := 1;
    
    constant CSR_BR_COMMIT : integer := 0;
    constant CSR_BR_MISPRED_CDB : integer := 1;
    constant CSR_BR_MISPRED_FE : integer := 2;
    constant CSR_BC_EMPTY : integer := 3;
    constant CSR_DCACHE_ACC : integer := 4;
    constant CSR_DCACHE_MISS : integer := 5;
    constant CSR_ICACHE_STALL : integer := 6;
    constant CSR_ISSUE_STALL_CYC : integer := 7;
    constant CSR_FIFO_FULL : integer := 8;
    constant CSR_RAA_EMPTY : integer := 9;
    constant CSR_ROB_FULL : integer := 10;
    constant CSR_SCHED_FULL : integer := 11;
    constant CSR_LQ_FULL : integer := 12;
    constant CSR_SQ_FULL : integer := 13;

    type csr_regs_64_type is array (1 downto 0) of std_logic_vector(63 downto 0);      -- 0: RDTIME AND RDCYCLE | 1: INSTRET
    type csr_regs_32_type is array (13 downto 0) of std_logic_vector(31 downto 0);
    signal csr_regs_64 : csr_regs_64_type;
    signal csr_regs_32 : csr_regs_32_type;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                csr_regs_32 <= (others => (others => '0'));
                csr_regs_64 <= (others => (others => '0'));
            else
                csr_regs_64(CSR_CYCLES) <= std_logic_vector(unsigned(csr_regs_64(CSR_CYCLES)) + 1);
                
                if (instr_ret = '1') then
                    csr_regs_64(CSR_INSTRET) <= std_logic_vector(unsigned(csr_regs_64(CSR_INSTRET)) + 1);
                end if;
                
                if (CSR_PERF_CNTR_BRANCHES = true) then
                    if (perfcntr_br_commit = '1') then
                        csr_regs_32(CSR_BR_COMMIT) <= std_logic_vector(unsigned(csr_regs_32(CSR_BR_COMMIT)) + 1);
                    end if;
                    
                    if (perfcntr_br_mispred_cdb = '1') then
                        csr_regs_32(CSR_BR_MISPRED_CDB) <= std_logic_vector(unsigned(csr_regs_32(CSR_BR_MISPRED_CDB)) + 1);
                    end if;
                    
                    if (perfcntr_br_mispred_fe = '1') then
                        csr_regs_32(CSR_BR_MISPRED_FE) <= std_logic_vector(unsigned(csr_regs_32(CSR_BR_MISPRED_FE)) + 1);
                    end if;
                    
                    if (perfcntr_bc_empty = '1') then
                        csr_regs_32(CSR_BC_EMPTY) <= std_logic_vector(unsigned(csr_regs_32(CSR_BC_EMPTY)) + 1);
                    end if;
                end if;
                
                if (CSR_PERF_CNTR_DMEM = true) then
                    if (dcache_access = '1') then
                        csr_regs_32(CSR_DCACHE_ACC) <= std_logic_vector(unsigned(csr_regs_32(CSR_DCACHE_ACC)) + 1);
                    end if;
                    
                    if (dcache_miss = '1') then
                        csr_regs_32(CSR_DCACHE_MISS) <= std_logic_vector(unsigned(csr_regs_32(CSR_DCACHE_MISS)) + 1);
                    end if;
                end if;
                
                if (CSR_PERF_CNTR_IMEM = true) then
                    if (perfcntr_icache_stall = '1') then
                        csr_regs_32(CSR_ICACHE_STALL) <= std_logic_vector(unsigned(csr_regs_32(CSR_ICACHE_STALL)) + 1);
                    end if;
                end if;
                
                if (CSR_PERF_CNTR_EE = true) then
                    if (perfcntr_issue_stall_cycles = '1') then
                        csr_regs_32(CSR_ISSUE_STALL_CYC) <= std_logic_vector(unsigned(csr_regs_32(CSR_ISSUE_STALL_CYC)) + 1);
                    end if;
                    
                    if (perfcntr_fifo_full = '1') then
                        csr_regs_32(CSR_FIFO_FULL) <= std_logic_vector(unsigned(csr_regs_32(CSR_FIFO_FULL)) + 1);
                    end if;
                    
                    if (perfcntr_raa_empty = '1') then
                        csr_regs_32(CSR_RAA_EMPTY) <= std_logic_vector(unsigned(csr_regs_32(CSR_RAA_EMPTY)) + 1);
                    end if;
                    
                    if (perfcntr_rob_full = '1') then
                        csr_regs_32(CSR_ROB_FULL) <= std_logic_vector(unsigned(csr_regs_32(CSR_ROB_FULL)) + 1);
                    end if;
                    
                    if (perfcntr_sched_full = '1') then
                        csr_regs_32(CSR_SCHED_FULL) <= std_logic_vector(unsigned(csr_regs_32(CSR_SCHED_FULL)) + 1);
                    end if;
                    
                    if (perfcntr_lq_full = '1') then
                        csr_regs_32(CSR_LQ_FULL) <= std_logic_vector(unsigned(csr_regs_32(CSR_LQ_FULL)) + 1);
                    end if;
                    
                    if (perfcntr_sq_full = '1') then
                        csr_regs_32(CSR_SQ_FULL) <= std_logic_vector(unsigned(csr_regs_32(CSR_SQ_FULL)) + 1);
                    end if;
                end if;
            end if;         
        end if;
    end process;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            case read_addr is 
                when X"C00" => read_data <= csr_regs_64(CSR_CYCLES)(31 downto 0);            -- RDCYCLE
                when X"C01" => read_data <= csr_regs_64(CSR_CYCLES)(31 downto 0);            -- RDTIME
                when X"C02" => read_data <= csr_regs_64(CSR_INSTRET)(31 downto 0);            -- INSTRET
               
                when X"C03" => if (CSR_PERF_CNTR_BRANCHES = true) then read_data <= csr_regs_32(CSR_BR_COMMIT); else read_data <= (others => '0'); end if;            -- BRANCHES EXECUTED
                when X"C04" => if (CSR_PERF_CNTR_BRANCHES = true) then read_data <= csr_regs_32(CSR_BR_MISPRED_CDB); else read_data <= (others => '0'); end if;           -- BRANCHES MISPREDICTED ON CDB
                when X"C05" => if (CSR_PERF_CNTR_BRANCHES = true) then read_data <= csr_regs_32(CSR_BR_MISPRED_FE); else read_data <= (others => '0'); end if;           -- BRANCHES MISPREDICTED IN FE 
                when X"C06" => if (CSR_PERF_CNTR_BRANCHES = true) then read_data <= csr_regs_32(CSR_BC_EMPTY); else read_data <= (others => '0'); end if;           -- BRANCHES MISPREDICTED IN FE 
                
                when X"C07" => if (CSR_PERF_CNTR_DMEM = true) then read_data <= csr_regs_32(CSR_DCACHE_ACC); else read_data <= (others => '0'); end if;            --  DCACHE ACCESSES
                when X"C08" => if (CSR_PERF_CNTR_DMEM = true) then read_data <= csr_regs_32(CSR_DCACHE_MISS); else read_data <= (others => '0'); end if;           --  DCACHE MISSES
                
                when X"C09" => if (CSR_PERF_CNTR_IMEM = true) then read_data <= csr_regs_32(CSR_ICACHE_STALL); else read_data <= (others => '0'); end if;           --  ICACHE STALL CYCLES
                
                when X"C0A" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_ISSUE_STALL_CYC); else read_data <= (others => '0'); end if;           
                when X"C0B" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_FIFO_FULL); else read_data <= (others => '0'); end if;       
                when X"C0C" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_RAA_EMPTY); else read_data <= (others => '0'); end if;       
                when X"C0D" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_ROB_FULL); else read_data <= (others => '0'); end if;          
                when X"C0E" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_SCHED_FULL); else read_data <= (others => '0'); end if;       
                when X"C0F" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_LQ_FULL); else read_data <= (others => '0'); end if;    
                when X"C10" => if (CSR_PERF_CNTR_EE = true) then read_data <= csr_regs_32(CSR_SQ_FULL); else read_data <= (others => '0'); end if;       
                
                when X"C80" => read_data <= csr_regs_64(CSR_CYCLES)(63 downto 32);           -- RDCYCLE
                when X"C81" => read_data <= csr_regs_64(CSR_CYCLES)(63 downto 32);           -- RDTIME
                when X"C82" => read_data <= csr_regs_64(CSR_INSTRET)(63 downto 32);           -- INSTRET
                
                when others => read_data <= (others => '0');
            end case;
        end if;
    end process;

end rtl;
