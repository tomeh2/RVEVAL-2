library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use WORK.CONFIG.ALL;

library neorv32;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity soc is
    port(
        gpio_o : out std_logic_vector(31 downto 0);
        gpio_i : in std_logic_vector(31 downto 0);
    
        uart_tx : out std_logic;
        uart_rx : in std_logic;
    
        clk : in std_logic;
        reset : in std_logic
    );
end soc;

architecture rtl of soc is
    component picorv32
		generic(
			STACKADDR : std_logic_vector(31 downto 0) := STACK_ADDR;
			PROGADDR_RESET : std_logic_vector(31 downto 0) := RESET_PC
			/*ENABLE_COUNTERS : boolean := true;
			ENABLE_COUNTERS64 : boolean := true;
			ENABLE_REGS_16_31 : boolean := true;
			ENABLE_REGS_DUALPORT : boolean := true;
			LATCHED_MEM_RDATA : boolean := false;
			TWO_STAGE_SHIFT : boolean := true;
			BARREL_SHIFTER : boolean := true;
			TWO_CYCLE_COMPARE : boolean := false;
			TWO_CYCLE_ALU : boolean := false;
			COMPRESSED_ISA : boolean := false;
			CATCH_ILLINSN : boolean := true;
			ENABLE_PCPI : boolean := false;
			ENABLE_MUL : boolean := false;
			ENABLE_DIV : boolean := false;
			ENABLE_FAST_MUL : boolean := false;
			ENABLE_IRQ : boolean := false;
			ENABLE_IRQ_QREGS : boolean := true;
			ENABLE_IRQ_TIMER : boolean := true;
			ENABLE_TRACE : boolean := false;
			REGS_INIT_ZERO : boolean := true;
			MASKED_IRQ : std_logic_vector(31 downto 0) := (others => '0');
			LATCHED_IRQ : std_logic_vector(31 downto 0) := (others => '0');
			PROGADDR_IRQ : std_logic_vector(31 downto 0) := (others => '0')*/
		);
		port(
			mem_valid : out std_logic;
			mem_instr : out std_logic;
			mem_ready : in std_logic;
			mem_addr : out std_logic_vector(31 downto 0);
			mem_wdata : out std_logic_vector(31 downto 0);
			mem_wstrb : out std_logic_vector(3 downto 0);
			mem_rdata : in std_logic_vector(31 downto 0);
			
			pcpi_wr : in std_logic;
			pcpi_rd : in std_logic_vector(31 downto 0);
			pcpi_ready : in std_logic;
			pcpi_wait : in std_logic;
			
			mem_la_read : out std_logic;
			mem_la_write : out std_logic;
			mem_la_addr : out std_logic_vector(31 downto 0);
			mem_la_wdata : out std_logic_vector(31 downto 0);
			mem_la_wstrb : out std_logic_vector(3 downto 0);
			
			pcpi_valid : out std_logic;
			pcpi_insn : out std_logic_vector(31 downto 0);
			pcpi_rs1 : out std_logic_vector(31 downto 0);
			pcpi_rs2 : out std_logic_vector(31 downto 0);
			
			irq : in std_logic_vector(31 downto 0);
			eoi : out std_logic_vector(31 downto 0);
			
			trace_valid : out std_logic;
			trace_data : out std_logic_vector(35 downto 0);
			
			trap : out std_logic;
			clk : in std_logic;
			resetn : in std_logic
		);
	end component;
	
	component serv_rf_top
        generic(
            RESET_PC : std_logic_vector(31 downto 0) := RESET_PC;
            COMPRESSED : boolean := false;
            ALIGN : boolean := false;
            MDU : boolean := false;
            PRE_REGISTER : integer := 1;
            RESET_STRATEGY : string := "MINI";
            WITH_CSR : integer := 1;
            RF_WIDTH : integer := 2
            );
        port(clk : in std_logic;
             i_rst : in std_logic;
             i_timer_irq : in std_logic;
             
--             rvfi_valid : out std_logic;
--             rvfi_order : out std_logic_vector(63 downto 0);
--             rvfi_insn : out std_logic_vector(31 downto 0);
--             rvfi_trap : out std_logic;
--             rvfi_halt : out std_logic;
--             rvfi_intr : out std_logic;
--             rvfi_mode : out std_logic_vector(1 downto 0);
--             rvfi_ixl : out std_logic_vector(1 downto 0);
--             rvfi_rs1_addr : out std_logic_vector(4 downto 0);
--             rvfi_rs2_addr : out std_logic_vector(4 downto 0);
--             rvfi_rs1_rdata : out std_logic_vector(31 downto 0);
--             rvfi_rs2_rdata : out std_logic_vector(31 downto 0);
--             rvfi_rd_addr : out std_logic_vector(4 downto 0);
--             rvfi_rd_wdata : out std_logic_vector(31 downto 0);
--             rvfi_pc_rdata : out std_logic_vector(31 downto 0);
--             rvfi_pc_wdata : out std_logic_vector(31 downto 0);
--             rvfi_mem_addr : out std_logic_vector(31 downto 0);
--             rvfi_mem_rmask : out std_logic_vector(3 downto 0);
--             rvfi_mem_wmask : out std_logic_vector(3 downto 0);
--             rvfi_mem_wdata : out std_logic_vector(31 downto 0);
--             rvfi_mem_rdata : out std_logic_vector(31 downto 0);
             
             o_ibus_adr : out std_logic_vector(31 downto 0);
             o_ibus_cyc : out std_logic;
             i_ibus_rdt : in std_logic_vector(31 downto 0);
             i_ibus_ack : in std_logic;
             o_dbus_adr : out std_logic_vector(31 downto 0);
             o_dbus_dat : out std_logic_vector(31 downto 0);
             o_dbus_sel : out std_logic_vector(3 downto 0);
             o_dbus_we : out std_logic;
             o_dbus_cyc : out std_logic;
             i_dbus_rdt : in std_logic_vector(31 downto 0);
             i_dbus_ack : in std_logic;
             
             i_ext_rd : in std_logic_vector(31 downto 0) := (others => '0');
             i_ext_ready : in std_logic := '0'
             );
	end component;
	
	component darkriscv
        port(
                CLK : in std_logic;
                RES : in std_logic;
                HLT : in std_logic;
                
                IDATA : in std_logic_vector(31 downto 0);
                IADDR : out std_logic_vector(31 downto 0);
                
                DATAI : in std_logic_vector(31 downto 0);
                DATAO : out std_logic_vector(31 downto 0);
                DADDR : out std_logic_vector(31 downto 0);
                
                BE : out std_logic;
                WR : out std_logic;
                RD : out std_logic;
                
                IDLE : out std_logic;
                DEBUG : out std_logic_vector(3 downto 0)
             );
	end component;
    
    component simpleuart
		port(
			clk : in std_logic;
			resetn : in std_logic;
			
			ser_tx : out std_logic;
			ser_rx : in std_logic;
			
			reg_div_we : in std_logic_vector(3 downto 0);
			reg_div_di : in std_logic_vector(31 downto 0);
			reg_div_do : out std_logic_vector(31 downto 0);
			
			reg_dat_we : in std_logic;
			reg_dat_re : in std_logic;
			
			reg_dat_di : in std_logic_vector(31 downto 0);
			reg_dat_do : out std_logic_vector(31 downto 0);
			reg_dat_wait : out std_logic
		);
	end component;

    signal wb_icpu_rdata : std_logic_vector(31 downto 0);
    signal wb_icpu_wdata : std_logic_vector(31 downto 0);
    signal wb_icpu_addr : std_logic_vector(31 downto 0);
    signal wb_icpu_wstrb : std_logic_vector(3 downto 0);
    signal wb_icpu_cyc : std_logic;
    signal wb_icpu_ack : std_logic;
    
    signal wb_dcpu_rdata : std_logic_vector(31 downto 0);
    signal wb_dcpu_wdata : std_logic_vector(31 downto 0);
    signal wb_dcpu_addr : std_logic_vector(31 downto 0);
    signal wb_dcpu_wstrb : std_logic_vector(3 downto 0);
    signal wb_dcpu_we : std_logic;
    signal wb_dcpu_cyc : std_logic;
    signal wb_dcpu_ack : std_logic;
    
    signal wb_wren : std_logic;
    signal wb_wdata : std_logic_vector(31 downto 0);
    signal wb_addr : std_logic_vector(31 downto 0);
    signal wb_wstrb : std_logic_vector(3 downto 0);
    
    signal wb_uart_rdata : std_logic_vector(31 downto 0);
    signal wb_uart_cyc : std_logic;
    signal wb_uart_ack : std_logic;
    signal uart_byte_sel : std_logic_vector(3 downto 0);
    
    signal wb_ram_rdata : std_logic_vector(31 downto 0);
    signal wb_ram_cyc : std_logic;
    signal wb_ram_ack : std_logic;
    
    signal wb_rom_rdata : std_logic_vector(31 downto 0);
    signal wb_rom_cyc : std_logic;
    signal wb_rom_ack : std_logic;
    
    signal wb_gpio_rdata : std_logic_vector(31 downto 0);
    signal wb_gpio_cyc : std_logic;
    signal wb_gpio_ack : std_logic;
begin
    neo_gen : if (CPU_NAME = "NEORV") generate
        neorv32_inst: entity neorv32.neorv32_top(neorv32_top_rtl)
                      generic map (
                        -- General --
                        CLOCK_FREQUENCY              => CLOCK_FREQ_MHZ * 1000000,  -- clock frequency of clk_i in Hz
                        INT_BOOTLOADER_EN            => false,            -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
                    
                        -- On-Chip Debugger (OCD) --
                        ON_CHIP_DEBUGGER_EN          => false,  -- implement on-chip debugger?
                    
                        -- RISC-V CPU Extensions --
                        CPU_EXTENSION_RISCV_C        => false,         -- implement compressed extension?
                        CPU_EXTENSION_RISCV_E        => false,         -- implement embedded RF extension?
                        CPU_EXTENSION_RISCV_M        => false,         -- implement mul/div extension?
                        CPU_EXTENSION_RISCV_U        => false,         -- implement user mode extension?
                        CPU_EXTENSION_RISCV_Zfinx    => false,     -- implement 32-bit floating-point extension (using INT regs!)
                        CPU_EXTENSION_RISCV_Zicsr    => true,     -- implement CSR system?
                        CPU_EXTENSION_RISCV_Zicntr   => true,                          -- implement base counters?
                        CPU_EXTENSION_RISCV_Zifencei => false,  -- implement instruction stream sync.?
                    
                        -- Extension Options --
                        FAST_MUL_EN                  => false,    -- use DSPs for M extension's multiplier
                        FAST_SHIFT_EN                => false,  -- use barrel shifter for shift operations

                        -- Internal Instruction memory --
                        MEM_INT_IMEM_EN              => false,       -- implement processor-internal instruction memory
                        MEM_INT_IMEM_SIZE            => 32768,     -- size of processor-internal instruction memory in bytes
                    
                        -- Internal Data memory --
                        MEM_INT_DMEM_EN              => false,       -- implement processor-internal data memory
                        MEM_INT_DMEM_SIZE            => 32768,     -- size of processor-internal data memory in bytes
                    
                        -- Internal Cache memory --
                        ICACHE_EN                    => false,             -- implement instruction cache
                        ICACHE_NUM_BLOCKS            => 1,     -- i-cache: number of blocks (min 1), has to be a power of 2
                        ICACHE_BLOCK_SIZE            => 4,     -- i-cache: block size in bytes (min 4), has to be a power of 2
                        ICACHE_ASSOCIATIVITY         => 1,  -- i-cache: associativity / number of sets (1=direct_mapped), has to be a power of 2
                    
                        -- External memory interface --
                        MEM_EXT_EN                   => true,       -- implement external memory bus interface?
                        MEM_EXT_TIMEOUT              => 0,           -- cycles after a pending bus access auto-terminates (0 = disabled)
                    
                        -- Processor peripherals --
                        IO_GPIO_EN                   => false,         -- implement general purpose input/output port unit (GPIO)?
                        IO_MTIME_EN                  => true,   -- implement machine system timer (MTIME)?
                        IO_UART0_EN                  => false,         -- implement primary universal asynchronous receiver/transmitter (UART0)?
                        IO_UART1_EN                  => false,         -- implement secondary universal asynchronous receiver/transmitter (UART1)?
                        IO_SPI_EN                    => false,         -- implement serial peripheral interface (SPI)?
                        IO_TWI_EN                    => false,         -- implement two-wire interface (TWI)?
                        IO_PWM_NUM_CH                => 0, -- number of PWM channels to implement (0..60); 0 = disabled
                        IO_WDT_EN                    => false,     -- implement watch dog timer (WDT)?
                        IO_TRNG_EN                   => false,         -- implement true random number generator (TRNG)?
                        IO_CFS_EN                    => false,         -- implement custom functions subsystem (CFS)?
                        IO_CFS_CONFIG                => x"00000000",   -- custom CFS configuration generic
                        IO_CFS_IN_SIZE               => 32,            -- size of CFS input conduit in bits
                        IO_CFS_OUT_SIZE              => 32,            -- size of CFS output conduit in bits
                        IO_NEOLED_EN                 => false          -- implement NeoPixel-compatible smart LED interface (NEOLED)?
                      )
                      port map (
                        -- Global control --
                        clk_i       => clk,                        -- global clock, rising edge
                        rstn_i      => not reset,                       -- global reset, low-active, async
                    
                        -- JTAG on-chip debugger interface (available if ON_CHIP_DEBUGGER_EN = true) --
                        jtag_trst_i => '0',                          -- low-active TAP reset (optional)
                        jtag_tck_i  => '0',                          -- serial clock
                        jtag_tdi_i  => '0',                          -- serial data input
                        jtag_tdo_o  => open,                         -- serial data output
                        jtag_tms_i  => '0',                          -- mode select
                    
                        -- Wishbone bus interface (available if MEM_EXT_EN = true) --
                        wb_tag_o    => open,                         -- request tag
                        wb_adr_o    => wb_dcpu_addr,                         -- address
                        wb_dat_i    => wb_dcpu_rdata,              -- read data
                        wb_dat_o    => wb_dcpu_wdata,                         -- write data
                        wb_we_o     => wb_dcpu_we,                         -- read/write
                        wb_sel_o    => wb_dcpu_wstrb,                         -- byte enable
                        wb_stb_o    => open,                         -- strobe
                        wb_cyc_o    => wb_dcpu_cyc,                         -- valid cycle
                        wb_ack_i    => wb_dcpu_ack,                          -- transfer acknowledge
                        wb_err_i    => '0',                          -- transfer error
                    
                        -- Advanced memory control signals (available if MEM_EXT_EN = true) --
                        fence_o     => open,                         -- indicates an executed FENCE operation
                        fencei_o    => open,                         -- indicates an executed FENCEI operation
                    
                        -- GPIO (available if IO_GPIO_EN = true) --
                        gpio_o      => open,                         -- parallel output
                        gpio_i      => (others => '0'),              -- parallel input
                    
                        -- primary UART0 (available if IO_UART0_EN = true) --
                        uart0_txd_o => open,                         -- UART0 send data
                        uart0_rxd_i => '0',                          -- UART0 receive data
                        uart0_rts_o => open,                         -- hw flow control: UART0.RX ready to receive ("RTR"), low-active, optional
                        uart0_cts_i => '0',                          -- hw flow control: UART0.TX allowed to transmit, low-active, optional
                    
                        -- secondary UART1 (available if IO_UART1_EN = true) --
                        uart1_txd_o => open,                         -- UART1 send data
                        uart1_rxd_i => '0',                          -- UART1 receive data
                        uart1_rts_o => open,                         -- hw flow control: UART1.RX ready to receive ("RTR"), low-active, optional
                        uart1_cts_i => '0',                          -- hw flow control: UART1.TX allowed to transmit, low-active, optional
                    
                        -- SPI (available if IO_SPI_EN = true) --
                        spi_sck_o   => open,                         -- SPI serial clock
                        spi_sdo_o   => open,                         -- controller data out, peripheral data in
                        spi_sdi_i   => '0',                          -- controller data in, peripheral data out
                        spi_csn_o   => open,                         -- SPI CS
                    
                        -- TWI (available if IO_TWI_EN = true) --
                        twi_sda_io  => open,                         -- twi serial data line
                        twi_scl_io  => open,                         -- twi serial clock line
                    
                        -- PWM (available if IO_PWM_NUM_CH > 0) --
                        pwm_o       => open,                    -- pwm channels
                    
                        -- Custom Functions Subsystem IO --
                        cfs_in_i    => (others => '0'),              -- custom CFS inputs conduit
                        cfs_out_o   => open,                         -- custom CFS outputs conduit
                    
                        -- NeoPixel-compatible smart LED interface (available if IO_NEOLED_EN = true) --
                        neoled_o    => open,                         -- async serial data line
                    
                        -- System time --
                        mtime_i     => (others => '0'),              -- current system time from ext. MTIME (if IO_MTIME_EN = false)
                        mtime_o     => open,                         -- current system time from int. MTIME (if IO_MTIME_EN = true)
                    
                        -- Interrupts --
                        mtime_irq_i => '0',                          -- machine timer interrupt, available if IO_MTIME_EN = false
                        msw_irq_i   => '0',                          -- machine software interrupt
                        mext_irq_i  => '0'                           -- machine external interrupt
                      );
    end generate;

    pico_gen : if (CPU_NAME = "PICORV") generate
        picorv32_inst: picorv32
            port map (
                clk => clk,
                resetn => not reset,
                mem_valid => wb_dcpu_cyc,
                mem_instr => open,
                mem_ready => wb_dcpu_ack,
                mem_addr => wb_dcpu_addr,
                mem_wdata => wb_dcpu_wdata,
                mem_wstrb => wb_dcpu_wstrb,
                mem_rdata => wb_dcpu_rdata,
            
                irq => (others => '0'),
            
                pcpi_wr => '0',
                pcpi_rd => X"0000_0000",
                pcpi_ready => '0',
                pcpi_wait => '0'
            );
        wb_dcpu_we <= '1' when wb_dcpu_wstrb /= "0000" else '0';
    end generate;
    
    serv_gen : if (CPU_NAME = "SERV") generate
        serv_inst: serv_rf_top
            port map (
                clk => clk,
                i_rst => reset,
                i_timer_irq => '0',
                
                o_ibus_adr => wb_icpu_addr,
                o_ibus_cyc => wb_icpu_cyc,
                i_ibus_rdt => wb_dcpu_rdata,
                i_ibus_ack => wb_icpu_ack,
                o_dbus_adr => wb_dcpu_addr,
                o_dbus_dat => wb_dcpu_wdata,
                o_dbus_sel => wb_dcpu_wstrb,
                o_dbus_we => wb_dcpu_we,
                o_dbus_cyc => wb_dcpu_cyc,
                i_dbus_rdt => wb_dcpu_rdata,
                i_dbus_ack => wb_dcpu_ack
            );
        wb_icpu_wstrb <= "0000";
    end generate;
    
    myrisc_gen : if (CPU_NAME = "MYRISC") generate
        myrisc_inst: entity work.core(structural)
                     port map(bus_addr_read => wb_icpu_addr,
                              bus_addr_write => wb_dcpu_addr,
                              bus_data_read => wb_dcpu_rdata,
                              bus_data_write => wb_dcpu_wdata,
                              bus_stbr => wb_icpu_cyc,
                              bus_stbw => wb_dcpu_wstrb,
                              bus_ackr => wb_icpu_ack,
                              bus_ackw => wb_dcpu_ack,
        
                              clk => clk,
                              
                              reset => reset);
        wb_icpu_wstrb <= "0000";
        wb_dcpu_cyc <= '1' when wb_dcpu_wstrb /= "0000" else '0';
        wb_dcpu_we <= '1' when wb_dcpu_wstrb /= "0000" else '0';
    end generate;


    neumann_gen : if (CPU_NAME = "NEORV" or CPU_NAME = "PICORV") generate
        interconnect_inst : entity work.wb_interconnect_bus(rtl)
                            generic map(DECODER_ADDR_WIDTH => 24,
                                        NUM_SLAVES => 4,
                                        NUM_MASTERS => 1,
                                        --BASE_ADDRS => (X"000003", X"8-----", X"1-----", X"000007"))
                                        BASE_ADDRS => (X"FFFFFB", X"8-----", X"0-----", X"FFFFFF"))
                            port map(wb_master_rdata => wb_dcpu_rdata,
                                     wb_master_wdata(31 downto 0) => wb_dcpu_wdata,
                                     wb_master_addr(31 downto 0) => wb_dcpu_addr,
                                     wb_master_wstrb(3 downto 0) => wb_dcpu_wstrb,
                                     wb_master_wren => wb_dcpu_we,
                                     wb_master_cyc(0) => wb_dcpu_cyc,
                                     wb_master_ack(0) => wb_dcpu_ack,
                                     
                                     wb_slave_rdata(31 downto 0) => wb_uart_rdata,
                                     wb_slave_rdata(63 downto 32) => wb_ram_rdata,
                                     wb_slave_rdata(95 downto 64) => wb_rom_rdata,
                                     wb_slave_rdata(127 downto 96) => wb_gpio_rdata,
                                     wb_slave_wdata => wb_wdata,
                                     wb_slave_addr => wb_addr,
                                     wb_slave_wstrb => wb_wstrb,
                                     
                                     wb_slave_wren => wb_wren,
                                     wb_slave_cyc(0) => wb_uart_cyc,
                                     wb_slave_cyc(1) => wb_ram_cyc,
                                     wb_slave_cyc(2) => wb_rom_cyc,
                                     wb_slave_cyc(3) => wb_gpio_cyc,
                                     wb_slave_ack(0) => wb_uart_ack,
                                     wb_slave_ack(1) => wb_ram_ack,
                                     wb_slave_ack(2) => wb_rom_ack,
                                     wb_slave_ack(3) => wb_gpio_ack,
                                     
                                     reset => reset,
                                     clk => clk);
    end generate;
    
    harvard_gen : if (CPU_NAME = "SERV" or CPU_NAME = "MYRISC") generate
        interconnect_inst : entity work.wb_interconnect_bus(rtl)
                            generic map(DECODER_ADDR_WIDTH => 24,
                                        NUM_SLAVES => 4,
                                        NUM_MASTERS => 2,
                                        BASE_ADDRS => (X"FFFFFB", X"8-----", X"0-----", X"FFFFFF"))
                            port map(wb_master_rdata => wb_dcpu_rdata,
                                     wb_master_wdata(31 downto 0) => wb_dcpu_wdata,
                                     wb_master_wdata(63 downto 32) => (others => '0'),
                                     wb_master_addr(31 downto 0) => wb_dcpu_addr,
                                     wb_master_addr(63 downto 32) => wb_icpu_addr,
                                     wb_master_wstrb(3 downto 0) => wb_dcpu_wstrb,
                                     wb_master_wstrb(7 downto 4) => wb_icpu_wstrb,
                                     wb_master_wren => wb_dcpu_we,
                                     wb_master_cyc(0) => wb_dcpu_cyc,
                                     wb_master_cyc(1) => wb_icpu_cyc,
                                     wb_master_ack(0) => wb_dcpu_ack,
                                     wb_master_ack(1) => wb_icpu_ack,
                                     
                                     wb_slave_rdata(31 downto 0) => wb_uart_rdata,
                                     wb_slave_rdata(63 downto 32) => wb_ram_rdata,
                                     wb_slave_rdata(95 downto 64) => wb_rom_rdata,
                                     wb_slave_rdata(127 downto 96) => wb_gpio_rdata,
                                     wb_slave_wdata => wb_wdata,
                                     wb_slave_addr => wb_addr,
                                     wb_slave_wstrb => wb_wstrb,
                                     
                                     wb_slave_wren => wb_wren,
                                     wb_slave_cyc(0) => wb_uart_cyc,
                                     wb_slave_cyc(1) => wb_ram_cyc,
                                     wb_slave_cyc(2) => wb_rom_cyc,
                                     wb_slave_cyc(3) => wb_gpio_cyc,
                                     wb_slave_ack(0) => wb_uart_ack,
                                     wb_slave_ack(1) => wb_ram_ack,
                                     wb_slave_ack(2) => wb_rom_ack,
                                     wb_slave_ack(3) => wb_gpio_ack,
                                     
                                     reset => reset,
                                     clk => clk);
    end generate;
                                 
    ram_memory_inst : entity work.ram_memory(rtl)
                      generic map(SIZE_BYTES => RAM_KB * 1024)
                      port map(bus_addr => wb_addr(18 downto 0),
                               bus_wdata => wb_wdata,
                               bus_rdata => wb_ram_rdata,
                               bus_wstrb => wb_wstrb,
                               bus_ready => wb_ram_ack,
                               bus_wren => wb_wren,
                               
                               en => wb_ram_cyc,
                               clk => clk,
                               resetn => not reset);
                               
    rom_memory_inst : entity work.rom_memory(rtl)
                      generic map(SIZE_BYTES => 1024,
                                  BOOTLOADER_PATH => BOOTLOADER_PATH)
                      port map(bus_addr => wb_addr(9 downto 0),
                               bus_rdata => wb_rom_rdata,
                               bus_ready => wb_rom_ack,
                               
                               en => wb_rom_cyc,
                               clk => clk,
                               resetn => not reset);
                                 
    sio_instance: entity work.sio
        generic map (
            C_clk_freq => CLOCK_FREQ_MHZ,
            C_init_baudrate => UART_BAUD_RATE,
            C_break_detect => false)
        port map (
            clk => clk,
            ce => wb_uart_cyc,
            txd => uart_tx,
            rxd => uart_rx,
            bus_write => wb_wren,
            byte_sel => uart_byte_sel,
            bus_in => wb_wdata,
            bus_out => wb_uart_rdata,
            bus_ack => wb_uart_ack,
            break => open
        );
        
        
        pico_sio_intf_gen :if (CPU_NAME = "PICORV" or CPU_NAME = "MYRISC") generate
            uart_byte_sel <= wb_wstrb when wb_wren = '1' else "0001";
        else generate
            uart_byte_sel <= wb_wstrb;
        end generate;
    
    gpio_instance : entity work.gpio
                    port map(gpio_i => gpio_i,
                             gpio_o => gpio_o,
                             
                             bus_wdata => wb_wdata,
                             bus_rdata => wb_gpio_rdata,
                             bus_stbw => wb_wstrb,
                             bus_cyc => wb_gpio_cyc,
                             bus_ack => wb_gpio_ack,
                             
                             clk => clk,
                             reset => reset);

end rtl;






