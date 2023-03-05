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

use work.pkg_axi.all;

package test is
    type to_master_array is array(3 downto 0) of FromMasterInterface;
    type from_master_array is array(3 downto 0) of ToMasterInterface;
    type to_slave_array is array(3 downto 0) of FromSlaveInterface;
    type from_slave_array is array(3 downto 0) of ToSlaveInterface;
end package test;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.pkg_axi.all;
use work.test.all;

entity axi_interconnect_simple is
    generic(
        NUM_MASTERS : integer;
        NUM_SLAVES : integer
    );
    port(
        to_masters : out to_master_array;
        from_masters : in from_master_array;
        
        to_slaves : out to_slave_array;
        from_slaves : in from_slave_array;
        
        clk : in std_logic;
        reset : in std_logic
    );
end axi_interconnect_simple;

architecture rtl of axi_interconnect_simple is
    -- ===== TYPE DEFINITIONS =====
    type write_addr_ch_master_array is array(0 to NUM_MASTERS - 1) of WriteAddressChannel;
    type write_data_ch_master_array is array(0 to NUM_MASTERS - 1) of WriteDataChannel; 
    type write_resp_ch_master_array is array(0 to NUM_MASTERS - 1) of WriteResponseChannel; 
    type read_addr_ch_master_array is array(0 to NUM_MASTERS - 1) of ReadAddressChannel; 
    type read_data_ch_master_array is array(0 to NUM_MASTERS - 1) of ReadDataChannel; 

    type write_addr_ch_slave_array is array(0 to NUM_SLAVES - 1) of WriteAddressChannel;
    type write_data_ch_slave_array is array(0 to NUM_SLAVES - 1) of WriteDataChannel; 
    type write_resp_ch_slave_array is array(0 to NUM_SLAVES - 1) of WriteResponseChannel; 
    type read_addr_ch_slave_array is array(0 to NUM_SLAVES - 1) of ReadAddressChannel; 
    type read_data_ch_slave_array is array(0 to NUM_SLAVES - 1) of ReadDataChannel; 
    
    type handshakes_read_master_array is array(0 to NUM_MASTERS - 1) of HandshakeReadMaster;
    type handshakes_write_master_array is array(0 to NUM_MASTERS - 1) of HandshakeWriteMaster;
    type handshakes_read_slave_array is array(0 to NUM_SLAVES - 1) of HandshakeReadSlave;
    type handshakes_write_slave_array is array(0 to NUM_SLAVES - 1) of HandshakeWriteSlave;
    -- ============================

    -- ===== MASTER AND SLAVE CONTROLLER INTERFACES =====
    signal write_addr_master_chs : write_addr_ch_master_array;
    signal write_data_master_chs : write_data_ch_master_array;
    signal write_resp_master_chs : write_resp_ch_master_array;
    signal read_addr_master_chs : read_addr_ch_master_array;
    signal read_data_master_chs : read_data_ch_master_array;
        
    signal write_addr_slave_chs : write_addr_ch_slave_array;
    signal write_data_slave_chs : write_data_ch_slave_array;
    signal write_resp_slave_chs : write_resp_ch_slave_array;
    signal read_addr_slave_chs : read_addr_ch_slave_array;
    signal read_data_slave_chs : read_data_ch_slave_array;
    
    signal handshakes_read_masters_to_bus : handshakes_read_master_array;
    signal handshakes_write_masters_to_bus : handshakes_write_master_array;
    signal handshakes_read_slaves_to_bus : handshakes_read_slave_array;
    signal handshakes_write_slaves_to_bus : handshakes_write_slave_array;
    
    signal handshakes_read_masters_from_bus : handshakes_read_master_array;
    signal handshakes_write_masters_from_bus : handshakes_write_master_array;
    signal handshakes_read_slaves_from_bus : handshakes_read_slave_array;
    signal handshakes_write_slaves_from_bus : handshakes_write_slave_array;
    -- ==================================================

    -- ===== BUS SIGNALS =====
    signal write_addr_bus_ch : WriteAddressChannel;
    signal write_data_bus_ch : WriteDataChannel;
    signal write_resp_bus_ch : WriteResponseChannel;
    signal read_addr_bus_ch : ReadAddressChannel;
    signal read_data_bus_ch : ReadDataChannel;
    
    signal handshake_read_master : HandshakeReadMaster;
    signal handshake_write_master : HandshakeWriteMaster;
    signal handshake_read_slave : HandshakeReadSlave;
    signal handshake_write_slave : HandshakeWriteSlave;
    -- =======================
    
    signal read_bus_disable : std_logic;
    signal write_bus_disable : std_logic;

    signal write_bus_slave_sel : std_logic_vector(3 downto 0);
    signal write_bus_master_sel : std_logic_vector(3 downto 0);
    
    signal read_bus_slave_sel : std_logic_vector(3 downto 0);
    signal read_bus_master_sel : std_logic_vector(3 downto 0);
    
    signal master_read_bus_reqs : std_logic_vector(3 downto 0);
    signal master_write_bus_reqs : std_logic_vector(3 downto 0);
begin
    axi_bus_read_controller : entity work.axi_bus_controller_simple(rtl)
                              generic map(NUM_MASTERS => NUM_MASTERS)
                              port map(master_bus_requests => master_read_bus_reqs,
                                       bus_address => read_addr_bus_ch.addr,
                                       master_sel => read_bus_master_sel,
                                       slave_sel => read_bus_slave_sel,
                                       bus_disable => read_bus_disable,
                                       clk => clk,
                                       reset => reset); 

    axi_bus_write_controller : entity work.axi_bus_controller_simple(rtl)
                              generic map(NUM_MASTERS => NUM_MASTERS)
                              port map(master_bus_requests => master_write_bus_reqs,
                                       bus_address => write_addr_bus_ch.addr,
                                       master_sel => write_bus_master_sel,
                                       slave_sel => write_bus_slave_sel,
                                       bus_disable => write_bus_disable,
                                       clk => clk,
                                       reset => reset); 
 
 
    --master_read_bus_reqs(3 downto 2) <= "00";
    --master_write_bus_reqs(3 downto 1) <= "000";
    
    GEN_MASTER_CONTROLLERS : for i in 0 to NUM_MASTERS - 1 generate
        master_controller : entity work.axi_master_interface(rtl)
                            port map(axi_write_addr_ch => write_addr_master_chs(i),
                                     axi_write_data_ch => write_data_master_chs(i),
                                     axi_write_resp_ch => write_resp_master_chs(i),
                                     axi_read_addr_ch => read_addr_master_chs(i),
                                     axi_read_data_ch => read_data_master_chs(i),
                                     
                                     master_write_handshake => handshakes_write_masters_to_bus(i),
                                     master_read_handshake => handshakes_read_masters_to_bus(i),
                                     slave_write_handshake => handshakes_write_slaves_from_bus(i),
                                     slave_read_handshake => handshakes_read_slaves_from_bus(i),
                                     
                                     to_device => to_masters(i),
                                     from_device => from_masters(i),
                                     
                                     bus_request_read => master_read_bus_reqs(i),
                                     bus_request_write => master_write_bus_reqs(i),
                                     
                                     clk => clk,
                                     reset => reset);
    end generate; 
    
    GEN_SLAVE_CONTROLLERS : for i in 0 to NUM_SLAVES - 1 generate
        master_controller : entity work.axi_slave_interface(rtl)
                            port map(axi_write_addr_ch => write_addr_slave_chs(i),
                                     axi_write_data_ch => write_data_slave_chs(i),
                                     axi_write_resp_ch => write_resp_slave_chs(i),
                                     axi_read_addr_ch => read_addr_slave_chs(i),
                                     axi_read_data_ch => read_data_slave_chs(i),
                                     
                                     master_write_handshake => handshakes_write_masters_from_bus(i),
                                     master_read_handshake => handshakes_read_masters_from_bus(i),
                                     slave_write_handshake => handshakes_write_slaves_to_bus(i),
                                     slave_read_handshake => handshakes_read_slaves_to_bus(i),
                                     
                                     to_device => to_slaves(i),
                                     from_device => from_slaves(i),
                                     
                                     clk => clk,
                                     reset => reset);
    end generate; 

    write_bus_chs_master_proc : process(write_bus_master_sel, write_addr_master_chs, write_data_master_chs, write_resp_bus_ch, handshakes_write_masters_to_bus, handshake_write_slave)
    begin
        if (write_bus_disable = '0' and write_bus_master_sel /= "1111") then
            write_addr_bus_ch <= write_addr_master_chs(to_integer(unsigned(write_bus_master_sel)));
            write_data_bus_ch <= write_data_master_chs(to_integer(unsigned(write_bus_master_sel)));

            write_resp_master_chs <= (others => WRITE_RESPONSE_CH_CLEAR);
            write_resp_master_chs(to_integer(unsigned(write_bus_master_sel))) <= write_resp_bus_ch;
            
            handshakes_write_slaves_from_bus <= (others => HANDSHAKE_WRITE_SLAVE_DEF);
            handshakes_write_slaves_from_bus(to_integer(unsigned(write_bus_master_sel))) <= handshake_write_slave;
        
            handshake_write_master <= handshakes_write_masters_to_bus(to_integer(unsigned(write_bus_master_sel)));
        else
            write_addr_bus_ch <= WRITE_ADDRESS_CH_CLEAR;
            write_data_bus_ch <= WRITE_DATA_CH_CLEAR;

            write_resp_master_chs <= (others => WRITE_RESPONSE_CH_CLEAR);
            
            handshakes_write_slaves_from_bus <= (others => HANDSHAKE_WRITE_SLAVE_DEF);
        
            handshake_write_master <= HANDSHAKE_WRITE_MASTER_DEF;
        end if;
    end process;
    
    write_bus_chs_slave_proc : process(write_bus_slave_sel, write_resp_slave_chs, write_addr_bus_ch, write_data_bus_ch, handshakes_write_slaves_to_bus, handshake_write_master)
    begin
        if (write_bus_disable = '0' and write_bus_slave_sel /= "1111") then
            write_resp_bus_ch <= write_resp_slave_chs(to_integer(unsigned(write_bus_slave_sel)));
        
            write_addr_slave_chs <= (others => WRITE_ADDRESS_CH_CLEAR);
            write_addr_slave_chs(to_integer(unsigned(write_bus_slave_sel))) <= write_addr_bus_ch;
            
            write_data_slave_chs <= (others => WRITE_DATA_CH_CLEAR);
            write_data_slave_chs(to_integer(unsigned(write_bus_slave_sel))) <= write_data_bus_ch;
            
            handshakes_write_masters_from_bus <= (others => HANDSHAKE_WRITE_MASTER_DEF);
            handshakes_write_masters_from_bus(to_integer(unsigned(write_bus_slave_sel))) <= handshake_write_master;
            
            handshake_write_slave <= handshakes_write_slaves_to_bus(to_integer(unsigned(write_bus_slave_sel)));
        else
            write_resp_bus_ch <= WRITE_RESPONSE_CH_CLEAR;
        
            write_addr_slave_chs <= (others => WRITE_ADDRESS_CH_CLEAR);
            write_data_slave_chs <= (others => WRITE_DATA_CH_CLEAR);
            
            handshakes_write_masters_from_bus <= (others => HANDSHAKE_WRITE_MASTER_DEF);
        
            handshake_write_slave <= HANDSHAKE_WRITE_SLAVE_DEF;
        end if;
    end process;
    
    read_bus_chs_master_proc : process(read_bus_master_sel, read_addr_master_chs, read_data_bus_ch, handshakes_read_masters_to_bus, handshake_read_slave, read_bus_disable)
    begin
        if (read_bus_disable = '0' and read_bus_master_sel /= "1111") then
            read_addr_bus_ch <= read_addr_master_chs(to_integer(unsigned(read_bus_master_sel)));
        
            read_data_master_chs <= (others => READ_DATA_CH_CLEAR);
            read_data_master_chs(to_integer(unsigned(read_bus_master_sel))) <= read_data_bus_ch;
            
            handshakes_read_slaves_from_bus <= (others => HANDSHAKE_READ_SLAVE_DEF);
            handshakes_read_slaves_from_bus(to_integer(unsigned(read_bus_master_sel))) <= handshake_read_slave;
        
            handshake_read_master <= handshakes_read_masters_to_bus(to_integer(unsigned(read_bus_master_sel)));
        else
            read_addr_bus_ch <= READ_ADDRESS_CH_CLEAR;
        
            read_data_master_chs <= (others => READ_DATA_CH_CLEAR);
            
            handshakes_read_slaves_from_bus <= (others => HANDSHAKE_READ_SLAVE_DEF);
        
            handshake_read_master <= HANDSHAKE_READ_MASTER_DEF;
        end if;
    end process;
    
    read_bus_chs_slave_proc : process(read_bus_slave_sel, read_data_slave_chs, read_addr_bus_ch, handshakes_read_slaves_to_bus, handshake_read_master, read_bus_disable)
    begin
        if (read_bus_disable = '0' and read_bus_slave_sel /= "1111") then
            read_data_bus_ch <= read_data_slave_chs(to_integer(unsigned(read_bus_slave_sel)));
        
            read_addr_slave_chs <= (others => READ_ADDRESS_CH_CLEAR);
            read_addr_slave_chs(to_integer(unsigned(read_bus_slave_sel))) <= read_addr_bus_ch;
        
            handshakes_read_masters_from_bus <= (others => HANDSHAKE_READ_MASTER_DEF);
            handshakes_read_masters_from_bus(to_integer(unsigned(read_bus_slave_sel))) <= handshake_read_master;
        
            handshake_read_slave <= handshakes_read_slaves_to_bus(to_integer(unsigned(read_bus_slave_sel)));
        else
            read_data_bus_ch <= READ_DATA_CH_CLEAR;
        
            read_addr_slave_chs <= (others => READ_ADDRESS_CH_CLEAR);
        
            handshakes_read_masters_from_bus <= (others => HANDSHAKE_READ_MASTER_DEF);
        
            handshake_read_slave <= HANDSHAKE_READ_SLAVE_DEF;
        end if;
    end process;
    
    --write_bus_master_sel <= (others => '0');
    --write_bus_slave_sel <= (others => '0');

end rtl;
















