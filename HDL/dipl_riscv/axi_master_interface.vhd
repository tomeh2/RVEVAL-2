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

use work.pkg_axi.all;

-- =================== TO DO =================== 
-- 1) Strobe generation for multiple bus widths
-- ============================================= 

entity axi_master_interface is
    port(
        -- CHANNEL SIGNALS
        axi_write_addr_ch : out WriteAddressChannel;
        axi_read_addr_ch : out ReadAddressChannel;
        
        axi_write_data_ch : out WriteDataChannel;
        axi_read_data_ch : in ReadDataChannel;
        
        axi_write_resp_ch : in WriteResponseChannel;
        
        -- HANDSHAKE SIGNALS
        master_write_handshake : out HandshakeWriteMaster; 
        master_read_handshake : out HandshakeReadMaster;
        slave_write_handshake : in HandshakeWriteSlave;
        slave_read_handshake : in HandshakeReadSlave;

        -- OTHER CONTROL SIGNALS
        to_device : out FromMasterInterface;
        from_device : in ToMasterInterface;
        
        bus_request_read : out std_logic;
        bus_request_write : out std_logic;
        
        clk : in std_logic;
        reset : in std_logic
    );
end axi_master_interface;

architecture rtl of axi_master_interface is
    type write_state_type is (IDLE,
                              ADDR_STATE_1,
                              DATA_STATE,
                              RESPONSE_STATE_1,
                              FINALIZE_STATE);
                              
    type read_state_type is (IDLE,
                             ADDR_STATE,
                             DATA_STATE,
                             FINALIZE_STATE);
                            
    -- ========== WRITE REGISTERS ==========                              
    signal write_addr_reg : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
    signal write_data_reg : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
    signal write_burst_len_init_reg : std_logic_vector(7 downto 0);
    signal write_burst_size_reg : std_logic_vector(2 downto 0);
    signal write_burst_type_reg : std_logic_vector(1 downto 0);
    signal write_regs_en : std_logic;
                              
    signal write_state_reg : write_state_type;
    signal write_state_next : write_state_type;
    
    signal write_burst_len_reg_zero : std_logic;
    signal write_burst_len_reg : std_logic_vector(7 downto 0);
    signal write_burst_len_next : std_logic_vector(7 downto 0);
    signal write_burst_len_reg_en : std_logic;
    signal write_burst_len_mux_sel : std_logic;
    
    -- ========== READ REGISTERS ==========
    signal read_addr_reg : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
    signal read_burst_len_reg : std_logic_vector(7 downto 0);
    signal read_burst_size_reg : std_logic_vector(2 downto 0);
    signal read_burst_type_reg : std_logic_vector(1 downto 0);
    signal read_regs_en : std_logic;
    
    signal read_data_reg : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
    signal read_data_reg_en : std_logic;
    
    signal read_state_reg : read_state_type;
    signal read_state_next : read_state_type;
    
    
begin
    -- WRITE STATE MACHINE
    write_state_transition : process(all)
    begin
        case write_state_reg is
            when IDLE =>
                if (from_device.execute_write = '1') then
                    write_state_next <= ADDR_STATE_1;
                else
                    write_state_next <= IDLE;
                end if;
            when ADDR_STATE_1 =>
                if (slave_write_handshake.awready = '1') then
                    write_state_next <= DATA_STATE;
                else
                    write_state_next <= ADDR_STATE_1;
                end if;
            when DATA_STATE => 
                if (slave_write_handshake.wready = '1' and write_burst_len_reg_zero = '1') then
                    write_state_next <= RESPONSE_STATE_1;
                else
                    write_state_next <= DATA_STATE;
                end if;
            when RESPONSE_STATE_1 => 
                if (slave_write_handshake.bvalid = '1') then
                    write_state_next <= FINALIZE_STATE;
                else 
                    write_state_next <= RESPONSE_STATE_1;
                end if;
            when FINALIZE_STATE => 
                if (from_device.done_write_ack = '1') then
                    write_state_next <= IDLE;
                else
                    write_state_next <= FINALIZE_STATE;
                end if;
        end case;
    end process;
    
    write_state_outputs : process(all)
    begin
        to_device.done_write <= '0'; 
        
        axi_write_addr_ch.addr <= (others => '0');
        axi_write_addr_ch.len <= (others => '0');
        axi_write_addr_ch.size <= (others => '0');
        axi_write_addr_ch.burst_type <= (others => '0');
        
        axi_write_data_ch.data <= (others => '0');
        axi_write_data_ch.strb <= "0000";      
        axi_write_data_ch.last <= '0';   
        
        master_write_handshake.awvalid <= '0';
        master_write_handshake.wvalid <= '0';
                
        master_write_handshake.bready <= '0';
        
        write_burst_len_mux_sel <= '0';
        write_burst_len_reg_en <= '0';
        
        bus_request_write <= '0';
        write_regs_en <= '0';
        case write_state_reg is
            when IDLE =>
                write_regs_en <= '1';
            when ADDR_STATE_1 => 
                -- WRITE ADDRESS CHANNEL
                axi_write_addr_ch.addr <= write_addr_reg;
                axi_write_addr_ch.len <= write_burst_len_reg;
                axi_write_addr_ch.size <= write_burst_size_reg;
                axi_write_addr_ch.burst_type <= write_burst_type_reg;
                
                -- WRITE DATA CHANNEL
                axi_write_data_ch.data <= write_data_reg;
                axi_write_data_ch.strb <= "1111";
                
                -- BURST CONTROL
                write_burst_len_reg_en <= '1';
                
                -- HANDSHAKE
                master_write_handshake.awvalid <= '1';
                
                bus_request_write <= '1';
            when DATA_STATE => 
                -- WRITE DATA CHANNEL
                axi_write_data_ch.data <= write_data_reg;
                axi_write_data_ch.strb <= "1111";
                axi_write_data_ch.last <= write_burst_len_reg_zero;
                
                -- HANDSHAKE
                master_write_handshake.wvalid <= '1';
                
                -- BURST CONTROL
                write_burst_len_mux_sel <= '1';
                write_burst_len_reg_en <= not write_burst_len_reg_zero and
                                          slave_write_handshake.wready;
                                          
                bus_request_write <= '1';
            when RESPONSE_STATE_1 =>
                master_write_handshake.bready <= '1';
             
                bus_request_write <= '1';
            when FINALIZE_STATE => 
                -- HANDSHAKE
                to_device.done_write <= '1';
                
                bus_request_write <= '1';
        end case;
    end process;
    
    -- ========== BURST LEN REGISTER CONTROL (WRITE) ==========
    write_burst_len_reg_zero <= not write_burst_len_reg(7) and
                               not write_burst_len_reg(6) and
                               not write_burst_len_reg(5) and
                               not write_burst_len_reg(4) and
                               not write_burst_len_reg(3) and
                               not write_burst_len_reg(2) and
                               not write_burst_len_reg(1) and
                               not write_burst_len_reg(0);
    
    write_burst_len_reg_cntrl : process(all)
    begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                write_burst_len_reg <= (others => '0');
            else
                if (write_burst_len_reg_en = '1') then
                    write_burst_len_reg <= write_burst_len_next;
                end if;
            end if;
        end if;
    end process;
    
    write_burst_len_next_mux_proc : process(write_burst_len_mux_sel, from_device.burst_len, write_burst_len_reg)
    begin
        if (write_burst_len_mux_sel = '0') then
            write_burst_len_next <= write_burst_len_init_reg;
        elsif (write_burst_len_mux_sel = '1') then
            write_burst_len_next <= std_logic_vector(unsigned(write_burst_len_reg) - 1);
        else
            write_burst_len_next <= (others => '0');
        end if;
    end process;
    
    -- ========== STROBE SIGNAL GENERATION (WRITE) ==========
    
    -- ============================================================================================
    -- READING
    -- ============================================================================================
    read_state_transition : process(read_state_reg, from_device.execute_read, slave_read_handshake.arready, axi_read_data_ch.last, slave_read_handshake.rvalid)
    begin
        case read_state_reg is 
            when IDLE => 
                if (from_device.execute_read = '1') then
                    read_state_next <= ADDR_STATE;
                else
                    read_state_next <= IDLE;
                end if;
            when ADDR_STATE => 
                if (slave_read_handshake.arready = '0') then
                    read_state_next <= DATA_STATE;
                else
                    read_state_next <= ADDR_STATE;
                end if;
            when DATA_STATE => 
                if (axi_read_data_ch.last = '1' and slave_read_handshake.rvalid = '1') then
                    read_state_next <= FINALIZE_STATE;
                else
                    read_state_next <= DATA_STATE;
                end if;
            when FINALIZE_STATE => 
                if (from_device.done_read_ack = '1') then
                    read_state_next <= IDLE;
                else
                    read_state_next <= FINALIZE_STATE;
                end if;
        end case;
    end process;
    
    read_state_outputs : process(all)
    begin
        axi_read_addr_ch.addr <= (others => '0');
        axi_read_addr_ch.len <= (others => '0');
        axi_read_addr_ch.size <= (others => '0');
        axi_read_addr_ch.burst_type <= (others => '0');
    
        to_device.done_read <= '0';
        
        bus_request_read <= '0';
        read_regs_en <= '0';
        -- HANDSHAKE
        master_read_handshake.arvalid <= '0';
        master_read_handshake.rready <= '0';
                
        read_data_reg_en <= '0';
        case read_state_reg is
            when IDLE =>
                read_regs_en <= '1';
            when ADDR_STATE => 
                bus_request_read <= '1';
                
                axi_read_addr_ch.addr <= read_addr_reg;
                axi_read_addr_ch.len <= read_burst_len_reg;
                axi_read_addr_ch.size <= read_burst_size_reg;
                axi_read_addr_ch.burst_type <= read_burst_type_reg;
                
                -- HANDSHAKE
                master_read_handshake.arvalid <= '1';
            when DATA_STATE => 
                bus_request_read <= '1';
            
                -- HANDSHAKE
                master_read_handshake.rready <= '1';
                
                read_data_reg_en <= slave_read_handshake.rvalid;
            when FINALIZE_STATE => 
                bus_request_read <= '1';
            
                to_device.done_read <= '1'; 
        end case;
    end process;
    
    process(all)
    begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                write_addr_reg <= (others => '0');
                write_data_reg <= (others => '0');
                
                read_data_reg <= (others => '0');
                read_burst_len_reg <= (others => '0');
                read_burst_size_reg <= (others => '0');
                read_burst_type_reg <= (others => '0');
                
                write_state_reg <= IDLE;
                read_state_reg <= IDLE;
            else
                if (write_regs_en = '1') then
                    write_addr_reg <= from_device.addr_write;
                    write_data_reg <= from_device.data_write;
                    write_burst_len_init_reg <= from_device.burst_len;
                    write_burst_size_reg <= from_device.burst_size;
                    write_burst_type_reg <= from_device.burst_type;
                end if;
                
                if (read_regs_en = '1') then
                    read_addr_reg <= from_device.addr_read;
                    read_burst_len_reg <= from_device.burst_len;
                    read_burst_size_reg <= from_device.burst_size;
                    read_burst_type_reg <= from_device.burst_type;
                end if;
                
                if (read_data_reg_en = '1') then
                    read_data_reg <= axi_read_data_ch.data;
                end if;
                
                write_state_reg <= write_state_next;
                read_state_reg <= read_state_next;
            end if;
        end if;
    end process;

    to_device.data_read <= read_data_reg;

end rtl;
