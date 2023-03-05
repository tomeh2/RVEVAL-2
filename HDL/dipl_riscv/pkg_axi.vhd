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

library ieee;
use ieee.std_logic_1164.all;

package pkg_axi is
    constant AXI_DATA_BUS_WIDTH : integer range 3 to 10 := 5;
    constant AXI_ADDR_BUS_WIDTH : integer range 3 to 10 := 5;

    type WriteAddressChannel is record
        addr : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        len : std_logic_vector(7 downto 0);     -- Burst length
        size : std_logic_vector(2 downto 0);    -- Num of bytes to transfer    
        burst_type : std_logic_vector(1 downto 0);   -- Burst type    
    end record WriteAddressChannel;
    
    type WriteDataChannel is record
        -- DATA
        data : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        -- CONTROL
        strb : std_logic_vector((2 ** AXI_DATA_BUS_WIDTH / 8) - 1 downto 0);
        last : std_logic;
    end record WriteDataChannel;
    
    type WriteResponseChannel is record
        resp : std_logic_vector(1 downto 0);    -- Response vector
    end record WriteResponseChannel;
    
    type ReadAddressChannel is record
        addr : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        len : std_logic_vector(7 downto 0);     -- Burst length
        size : std_logic_vector(2 downto 0);    -- Num of bytes to transfer
        burst_type : std_logic_vector(1 downto 0);   -- Burst type
    end record ReadAddressChannel;
    
    type ReadDataChannel is record
        data : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        resp : std_logic_vector(1 downto 0);    -- Response vector
        last : std_logic;
    end record ReadDataChannel;
    
    type HandshakeWriteMaster is record
        awvalid : std_logic;
        wvalid : std_logic;
        
        bready : std_logic;
    end record HandshakeWriteMaster;
    
    type HandshakeReadMaster is record
        arvalid : std_logic;
        
        rready : std_logic;
    end record HandshakeReadMaster;
    
    type HandshakeWriteSlave is record
        awready : std_logic;
        wready : std_logic;
        
        bvalid : std_logic;
    end record HandshakeWriteSlave;
    
    type HandshakeReadSlave is record
        arready : std_logic;
        
        rvalid : std_logic;
    end record HandshakeReadSlave;
    
    type ToMasterInterface is record
        -- Data signals
        data_write : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        
        -- Address signals
        addr_write : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        addr_read : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        
        -- Control signals
        burst_len : std_logic_vector(7 downto 0);
        burst_size : std_logic_vector(2 downto 0);
        burst_type : std_logic_vector(1 downto 0);
        
        execute_read : std_logic;
        execute_write : std_logic;
        
        done_read_ack : std_logic;
        done_write_ack : std_logic;
    end record ToMasterInterface;
    
    type FromMasterInterface is record
        -- Data signals
        data_read : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        
        -- Control signals
        done_read : std_logic;
        done_write : std_logic;
    end record FromMasterInterface;
    
    type ToSlaveInterface is record
        -- Data signals
        data : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        
        -- Address signals
        
        -- Control signals
        data_valid : std_logic;                     -- Is data on the data bus to the adapter valid 
        write_buffer_data_read : std_logic;         -- Tells the slave adapter that the device has read data in the write buffer in this cycle
    end record ToSlaveInterface;

    type FromSlaveInterface is record
        -- Data signals
        data_write : std_logic_vector(2 ** AXI_DATA_BUS_WIDTH - 1 downto 0);
        
        -- Address signals
        addr_read : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        addr_write : std_logic_vector(2 ** AXI_ADDR_BUS_WIDTH - 1 downto 0);
        
        addr_read_valid : std_logic;
        addr_write_valid : std_logic;
        
        -- Control signals
        write_buffer_full : std_logic;         -- These two signals indicate the state of this slave's DATA WRITE buffers. Masters fill these buffers when they execute a WRITE command 
        write_buffer_empty : std_logic;
        
        --read_buffer_full : std_logic;
        --read_buffer_empty : std_logic;
    end record FromSlaveInterface;
    
    -- ========== CONSTANTS ==========
    constant BURST_FIXED : std_logic_vector(1 downto 0) := "00";
    constant BURST_INCR : std_logic_vector(1 downto 0) := "01";
    constant BURST_WRAP : std_logic_vector(1 downto 0) := "10";
    
    constant RESP_OKAY : std_logic_vector(1 downto 0) := "00";
    constant RESP_EXOKAY : std_logic_vector(1 downto 0) := "01";
    constant RESP_SLVERR : std_logic_vector(1 downto 0) := "10";
    constant RESP_DECERR : std_logic_vector(1 downto 0) := "11";
    
    -- ========== CLEAR VALUES ==========
    constant TO_MASTER_CLEAR : ToMasterInterface := (data_write => (others => '0'),
                                                addr_write => (others => '0'),
                                                addr_read => (others => '0'),
                                                burst_len => (others => '0'),
                                                burst_size => (others => '0'),
                                                burst_type => (others => '0'),
                                                execute_read => '0',
                                                execute_write => '0',
                                                done_read_ack => '0',
                                                done_write_ack => '0');
                                                
    constant FROM_MASTER_CLEAR : FromMasterInterface := (data_read => (others => '0'),
                                                done_read => '0',
                                                done_write => '0');
                                                
    constant FROM_SLAVE_CLEAR : ToSlaveInterface := (data => (others => '0'),
                                              data_valid => '0',
                                              write_buffer_data_read => '0');
    
    constant WRITE_ADDRESS_CH_CLEAR : WriteAddressChannel := (addr => (others => '0'),
                                                              len => (others => '0'),
                                                              size => (others => '0'),
                                                              burst_type => (others => '0'));
                                                              
    constant WRITE_DATA_CH_CLEAR : WriteDataChannel := (data => (others => '0'),
                                                        strb => (others => '0'),
                                                        last => '0');
                                                        
    constant WRITE_RESPONSE_CH_CLEAR : WriteResponseChannel := (resp => (others => '0'));
    
    constant READ_ADDRESS_CH_CLEAR : ReadAddressChannel := (addr => (others => '0'),
                                                            len => (others => '0'),
                                                            size => (others => '0'),
                                                            burst_type => (others => '0'));
                                                             
    constant READ_DATA_CH_CLEAR : ReadDataChannel := (data => (others => '0'),
                                                      resp => (others => '0'),
                                                      last => '0');
                                                      
    constant HANDSHAKE_WRITE_MASTER_CLEAR : HandshakeWriteMaster := (awvalid => '0',
                                                                    wvalid => '0',
                                                                    bready => '0');
                                                                    
    constant HANDSHAKE_READ_MASTER_CLEAR : HandshakeReadMaster := (arvalid => '0',
                                                                   rready => '0');
                                                                   
    constant HANDSHAKE_WRITE_SLAVE_CLEAR : HandshakeWriteSlave := (awready => '0',
                                                                   wready => '0',
                                                                   bvalid => '0');
                                                                   
    constant HANDSHAKE_READ_SLAVE_CLEAR : HandshakeReadSlave := (arready => '0',
                                                                 rvalid => '0');
                                                                 
    -- DEFAULT SIGNALS
    constant HANDSHAKE_WRITE_MASTER_DEF : HandshakeWriteMaster := (awvalid => '0',
                                                                    wvalid => '0',
                                                                    bready => '0');
                                                                    
    constant HANDSHAKE_READ_MASTER_DEF : HandshakeReadMaster := (arvalid => '0',
                                                                   rready => '0');
                                                                   
    constant HANDSHAKE_WRITE_SLAVE_DEF : HandshakeWriteSlave := (awready => '0',
                                                                   wready => '0',
                                                                   bvalid => '0');
                                                                   
    constant HANDSHAKE_READ_SLAVE_DEF : HandshakeReadSlave := (arready => '1',
                                                                 rvalid => '0');
end pkg_axi;






