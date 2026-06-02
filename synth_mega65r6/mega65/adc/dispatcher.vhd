-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : dispatcher.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Simple command line interpreter
-- Data is left justified.
-- Commands available:
-- H               : Display help text
-- W AAAA DDDDDDDD : Write <DDDD> to <AAAA>
-- R AAAA          : Read from <AAAA>
-- K               : Read base address of I2C controller
-- K AAAA          : Set base address of KSZ controller
-- KSZ RR          : Read from KSZ address <RR>
-- KSZ RR VVVV     : Write <VVVV> to KSZ address <RR>
-- I               : Read base address of I2C controller
-- I AAAA          : Set base address of I2C controller
-- INA DD RR       : Read from I2C device <DD> address <RR>
-- INA DD RR VVVV  : Write <VVVV> to I2C device <DD> address <RR>
--
-- The output is a Wishbone Master interface 32-bit (Revision B.4)
-- https://cdn.opencores.org/downloads/wbspec_b4.pdf
-- ----------------------------------------------------------------------------
--
-- KSZ switch : https://ww1.microchip.com/downloads/en/DeviceDoc/IEEE1588-Precision-Time-Protocol-Enabled-Three-Port-10-100-Managed-Switch-with-MII-or-RMII-DS00002642A.pdf
-- See pages 54-55
--
-- R E004 -> 00000029
-- W E000 <- 09091F18 (32 clock cycles @ 5 MHz, CPOL=0, CPHA=0)
-- W E008 <- 000C0000 (read 2 bytes)
-- R E004 -> 00000009
-- R E008 -> 00005384 (must be swapped)
-- R E004 -> 00000029

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity dispatcher is
  generic (
    G_CLOCK_KHZ : natural;
    G_ADDR_SIZE : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    busy_o            : out   std_logic;
    timeout_o         : out   std_logic;

    -- W AAAA DDDDDDDD : Write <DDDD> to <AAAA>
    wr_addr_i         : in    std_logic_vector(15 downto 0);
    wr_data_i         : in    std_logic_vector(31 downto 0);
    wr_en_i           : in    std_logic;
    wr_ack_o          : out   std_logic;

    -- R AAAA          : Read from <AAAA>
    rd_addr_i         : in    std_logic_vector(15 downto 0);
    rd_en_i           : in    std_logic;
    rd_data_o         : out   std_logic_vector(31 downto 0);
    rd_ack_o          : out   std_logic;

    -- I               : Read base address of I2C controller
    i_rd_en_i         : in    std_logic;
    i_rd_addr_o       : out   std_logic_vector(15 downto 0);
    i_rd_ack_o        : out   std_logic;

    -- I AAAA          : Set base address of I2C controller
    i_wr_addr_i       : in    std_logic_vector(15 downto 0);
    i_wr_en_i         : in    std_logic;
    i_wr_ack_o        : out   std_logic;

    -- INA DD RR       : Read from I2C device <DD> address <RR>
    ina_rd_device_i   : in    std_logic_vector(7 downto 0);
    ina_rd_register_i : in    std_logic_vector(7 downto 0);
    ina_rd_en_i       : in    std_logic;
    ina_rd_data_o     : out   std_logic_vector(15 downto 0);
    ina_rd_ack_o      : out   std_logic;

    -- INA DD RR VVVV  : Write <VVVV> to I2C device <DD> address <RR>
    ina_wr_device_i   : in    std_logic_vector(7 downto 0);
    ina_wr_register_i : in    std_logic_vector(7 downto 0);
    ina_wr_data_i     : in    std_logic_vector(15 downto 0);
    ina_wr_en_i       : in    std_logic;
    ina_wr_ack_o      : out   std_logic;

    -- K               : Read base address of I2C controller
    k_rd_en_i         : in    std_logic;
    k_rd_addr_o       : out   std_logic_vector(15 downto 0);
    k_rd_ack_o        : out   std_logic;

    -- K AAAA          : Set base address of KSZ controller
    k_wr_addr_i       : in    std_logic_vector(15 downto 0);
    k_wr_en_i         : in    std_logic;
    k_wr_ack_o        : out   std_logic;

    -- KSZ RRRR        : Read from KSZ address <RRRR>
    ksz_rd_register_i : in    std_logic_vector(15 downto 0);
    ksz_rd_en_i       : in    std_logic;
    ksz_rd_data_o     : out   std_logic_vector(15 downto 0);
    ksz_rd_ack_o      : out   std_logic;

    -- KSZ RRRR VVVV   : Write <VVVV> to KSZ address <RRRR>
    ksz_wr_register_i : in    std_logic_vector(15 downto 0);
    ksz_wr_data_i     : in    std_logic_vector(15 downto 0);
    ksz_wr_en_i       : in    std_logic;
    ksz_wr_ack_o      : out   std_logic;

    -- Wishbone bus Master interface
    wbus_cyc_o        : out   std_logic;                                  -- Valid bus cycle
    wbus_stall_i      : in    std_logic;
    wbus_stb_o        : out   std_logic;                                  -- Strobe signals / core select signal
    wbus_addr_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    wbus_we_o         : out   std_logic;                                  -- Write enable
    wbus_wrdat_o      : out   std_logic_vector(31 downto 0);              -- Write Databus
    wbus_ack_i        : in    std_logic;                                  -- Bus cycle acknowledge
    wbus_rddat_i      : in    std_logic_vector(31 downto 0)               -- Read Databus
  );
end entity dispatcher;

architecture synthesis of dispatcher is

  type     state_type is (
    IDLE_ST, WR_ST, RD_ST,
    I2C_WRITE_DATA_ST, I2C_WRITE_CONFIG_ST, I2C_WAIT_DONE_ST, I2C_READ_DATA_ST,
    SPI_WRITE_CONFIG_ST, SPI_FLUSH_DATA_ST, SPI_WAIT_EMPTY_ST, SPI_WRITE_DATA_ST, SPI_WAIT_READ_FIFO_ST, SPI_READ_DATA_ST
  );

  signal   state : state_type                                            := IDLE_ST;

  signal   i2c_base_address : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#6000#, G_ADDR_SIZE));
  signal   i2c_device       : std_logic_vector(7 downto 0);
  signal   i2c_write_mode   : std_logic;
  signal   spi_base_address : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#E000#, G_ADDR_SIZE));
  signal   ksz_rd_en        : std_logic;
  signal   ksz_rd_register  : std_logic_vector(15 downto 0);
  signal   ksz_wr_en        : std_logic;
  signal   ksz_wr_register  : std_logic_vector(15 downto 0);
  signal   ksz_wr_data      : std_logic_vector(15 downto 0);
  constant C_TIMEOUT        : natural                                    := G_CLOCK_KHZ; -- 1 millisecond
  signal   timeout_cnt      : natural range 0 to C_TIMEOUT;

  constant C_I2C_WRITE_DATA : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#00#, G_ADDR_SIZE));
  constant C_I2C_READ_DATA  : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#20#, G_ADDR_SIZE));
  constant C_I2C_CONFIG     : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#80#, G_ADDR_SIZE));
  constant C_I2C_STATUS     : std_logic_vector(G_ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(16#84#, G_ADDR_SIZE));

  constant C_SPI_CONFIG : std_logic_vector(G_ADDR_SIZE - 1 downto 0)     := std_logic_vector(to_unsigned(16#00#, G_ADDR_SIZE));
  constant C_SPI_STATUS : std_logic_vector(G_ADDR_SIZE - 1 downto 0)     := std_logic_vector(to_unsigned(16#04#, G_ADDR_SIZE));
  constant C_SPI_DATA   : std_logic_vector(G_ADDR_SIZE - 1 downto 0)     := std_logic_vector(to_unsigned(16#08#, G_ADDR_SIZE));

  constant C_SPI_CONFIG_DATA : std_logic_vector(31 downto 0)             := x"09091F18";

begin

  busy_o <= '0' when state = IDLE_ST else
            '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if wbus_stall_i = '0' then
        wbus_stb_o <= '0';
      end if;

      if wbus_ack_i = '1' then
        wbus_cyc_o <= '0';
        wbus_stb_o <= '0';
      end if;

      wr_ack_o     <= '0';
      rd_ack_o     <= '0';
      i_rd_ack_o   <= '0';
      i_wr_ack_o   <= '0';
      ina_rd_ack_o <= '0';
      ina_wr_ack_o <= '0';
      k_rd_ack_o   <= '0';
      k_wr_ack_o   <= '0';
      ksz_rd_ack_o <= '0';
      ksz_wr_ack_o <= '0';
      timeout_o    <= '0';

      case state is

        when IDLE_ST =>
          ksz_wr_en <= '0';
          ksz_rd_en <= '0';

          if wr_en_i = '1' then
            -- W AAAA DDDDDDDD : Write <DDDD> to <AAAA>
            wbus_addr_o  <= wr_addr_i(G_ADDR_SIZE - 1 downto 0);
            wbus_wrdat_o <= wr_data_i;
            wbus_cyc_o   <= '1';
            wbus_stb_o   <= '1';
            wbus_we_o    <= '1';
            state        <= WR_ST;
          elsif rd_en_i = '1' then
            -- R AAAA          : Read from <AAAA>
            wbus_addr_o <= rd_addr_i(G_ADDR_SIZE - 1 downto 0);
            wbus_cyc_o  <= '1';
            wbus_stb_o  <= '1';
            wbus_we_o   <= '0';
            state       <= RD_ST;
          elsif i_rd_en_i = '1' then
            -- I               : Read base address of I2C controller
            i_rd_addr_o                           <= (others => '0');
            i_rd_addr_o(G_ADDR_SIZE - 1 downto 0) <= i2c_base_address;
            i_rd_ack_o                            <= '1';
            state                                 <= IDLE_ST;
          elsif i_wr_en_i = '1' then
            -- I AAAA          : Set base address of I2C controller
            i2c_base_address <= i_wr_addr_i(G_ADDR_SIZE - 1 downto 0);
            i_wr_ack_o       <= '1';
            state            <= IDLE_ST;
          elsif ina_rd_en_i = '1' then
            -- INA DD RR       : Read from I2C device <DD> address <RR>
            i2c_device     <= ina_rd_device_i;
            i2c_write_mode <= '0';
            wbus_addr_o    <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_WRITE_DATA));
            wbus_wrdat_o   <= ina_rd_register_i & x"000000";
            wbus_we_o      <= '1';
            wbus_cyc_o     <= '1';
            wbus_stb_o     <= '1';
            state          <= I2C_WRITE_DATA_ST;
          elsif ina_wr_en_i = '1' then
            -- INA DD RR VVVV  : Write <VVVV> to I2C device <DD> address <RR>
            i2c_device     <= ina_wr_device_i;
            i2c_write_mode <= '1';
            wbus_addr_o    <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_WRITE_DATA));
            -- Must be byte swapped
            wbus_wrdat_o   <= ina_wr_register_i & ina_wr_data_i(7 downto 0) & ina_wr_data_i(15 downto 8) & x"00";
            wbus_we_o      <= '1';
            wbus_cyc_o     <= '1';
            wbus_stb_o     <= '1';
            state          <= I2C_WRITE_DATA_ST;
          elsif k_rd_en_i = '1' then
            -- K               : Read base address of SPI controller
            k_rd_addr_o                           <= (others => '0');
            k_rd_addr_o(G_ADDR_SIZE - 1 downto 0) <= spi_base_address;
            k_rd_ack_o                            <= '1';
            state                                 <= IDLE_ST;
          elsif k_wr_en_i = '1' then
            -- K AAAA          : Set base address of SPI controller
            spi_base_address <= k_wr_addr_i(G_ADDR_SIZE - 1 downto 0);
            k_wr_ack_o       <= '1';
            state            <= IDLE_ST;
          elsif ksz_rd_en_i = '1' then
            -- KSZ RRRR        : Read from KSZ address <RRRR>
            ksz_rd_en       <= '1';
            ksz_rd_register <= ksz_rd_register_i;
            -- Write to the SPI Master config register
            wbus_addr_o     <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_CONFIG));
            wbus_wrdat_o    <= C_SPI_CONFIG_DATA;
            wbus_we_o       <= '1';
            wbus_cyc_o      <= '1';
            wbus_stb_o      <= '1';
            state           <= SPI_WRITE_CONFIG_ST;
          elsif ksz_wr_en_i = '1' then
            -- KSZ RRRR VVVV   : Write <VVVV> to KSZ address <RRRR>
            ksz_wr_en       <= '1';
            ksz_wr_register <= ksz_wr_register_i;
            ksz_wr_data     <= ksz_wr_data_i;
            -- Write to the SPI Master config register
            wbus_addr_o     <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_CONFIG));
            wbus_wrdat_o    <= C_SPI_CONFIG_DATA;
            wbus_we_o       <= '1';
            wbus_cyc_o      <= '1';
            wbus_stb_o      <= '1';
            state           <= SPI_WRITE_CONFIG_ST;
          end if;

        when WR_ST =>
          if wbus_ack_i = '1' then
            wr_ack_o <= '1';
            state    <= IDLE_ST;
          end if;

        when RD_ST =>
          if wbus_ack_i = '1' then
            rd_data_o <= wbus_rddat_i;
            rd_ack_o  <= '1';
            state     <= IDLE_ST;
          end if;

        when I2C_WRITE_DATA_ST =>
          if wbus_ack_i = '1' then
            if i2c_write_mode = '0' then
              wbus_addr_o  <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_CONFIG));
              -- Send 1 byte (register), read 2 bytes (value)
              wbus_wrdat_o <= x"020101" & i2c_device;
              wbus_we_o    <= '1';
              wbus_cyc_o   <= '1';
              wbus_stb_o   <= '1';
              state        <= I2C_WRITE_CONFIG_ST;
            else
              wbus_addr_o  <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_CONFIG));
              -- Send 3 bytes (register + value)
              wbus_wrdat_o <= x"000103" & i2c_device;
              wbus_we_o    <= '1';
              wbus_cyc_o   <= '1';
              wbus_stb_o   <= '1';
              state        <= I2C_WRITE_CONFIG_ST;
            end if;
          end if;

        when I2C_WRITE_CONFIG_ST =>
          if wbus_ack_i = '1' then
            wbus_addr_o <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_STATUS));
            wbus_we_o   <= '0';
            wbus_cyc_o  <= '1';
            wbus_stb_o  <= '1';
            state       <= I2C_WAIT_DONE_ST;
          end if;

        when I2C_WAIT_DONE_ST =>
          if wbus_ack_i = '1' then
            if wbus_rddat_i = x"00000031" then
              if i2c_write_mode = '0' then
                wbus_addr_o <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_READ_DATA));
                wbus_we_o   <= '0';
                wbus_cyc_o  <= '1';
                wbus_stb_o  <= '1';
                state       <= I2C_READ_DATA_ST;
              else
                ina_wr_ack_o <= '1';
                state        <= IDLE_ST;
              end if;
            else
              wbus_addr_o <= std_logic_vector(unsigned(i2c_base_address) + unsigned(C_I2C_STATUS));
              wbus_we_o   <= '0';
              wbus_cyc_o  <= '1';
              wbus_stb_o  <= '1';
              state       <= I2C_WAIT_DONE_ST;
            end if;
          end if;

        when I2C_READ_DATA_ST =>
          if wbus_ack_i = '1' then
            -- Result is byte swapped
            ina_rd_data_o <= wbus_rddat_i(23 downto 16) & wbus_rddat_i(31 downto 24);
            ina_rd_ack_o  <= '1';
            state         <= IDLE_ST;
          end if;

        when SPI_WRITE_CONFIG_ST =>
          if wbus_ack_i = '1' then
            -- We've written the SPI Master configuration, now we need to check the fifo's
            wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_STATUS));
            wbus_we_o   <= '0';
            wbus_cyc_o  <= '1';
            wbus_stb_o  <= '1';
            state       <= SPI_WAIT_EMPTY_ST;
          end if;

        when SPI_WAIT_EMPTY_ST =>
          if wbus_ack_i = '1' then
            -- We've read from the SPI Master status register
            if wbus_rddat_i(5) = '1' and wbus_rddat_i(3) = '1' then
              -- Both FIFO's are empty, proceed
              if ksz_rd_en = '1' then
                -- Send read request to SPI Slave
                wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_DATA));
                if ksz_rd_register(1) = '0' then
                  wbus_wrdat_o <= "0" & ksz_rd_register(10 downto 2) & "0011" & "00" & x"0000";
                else
                  wbus_wrdat_o <= "0" & ksz_rd_register(10 downto 2) & "1100" & "00" & x"0000";
                end if;
                wbus_we_o  <= '1';
                wbus_cyc_o <= '1';
                wbus_stb_o <= '1';
                state      <= SPI_WRITE_DATA_ST;
              elsif ksz_wr_en = '1' then
                -- Send write request to SPI Slave
                wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_DATA));
                -- Must be byte swapped
                if ksz_wr_register(1) = '0' then
                  wbus_wrdat_o <= "1" & ksz_wr_register(10 downto 2) & "0011" & "00" & ksz_wr_data(7 downto 0) & ksz_wr_data(15 downto 8);
                else
                  wbus_wrdat_o <= "1" & ksz_wr_register(10 downto 2) & "1100" & "00" & ksz_wr_data(7 downto 0) & ksz_wr_data(15 downto 8);
                end if;
                wbus_we_o  <= '1';
                wbus_cyc_o <= '1';
                wbus_stb_o <= '1';
                state      <= SPI_WRITE_DATA_ST;
              end if;
            else
              -- FIFO's not empty, read data and discard
              wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_DATA));
              wbus_we_o   <= '0';
              wbus_cyc_o  <= '1';
              wbus_stb_o  <= '1';
              state       <= SPI_FLUSH_DATA_ST;
            end if;
          end if;

        when SPI_FLUSH_DATA_ST =>
          if wbus_ack_i = '1' then
            -- Just discard the data we read, and read FIFO status again
            wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_STATUS));
            wbus_we_o   <= '0';
            wbus_cyc_o  <= '1';
            wbus_stb_o  <= '1';
            state       <= SPI_WAIT_EMPTY_ST;
          end if;

        when SPI_WRITE_DATA_ST =>
          if wbus_ack_i = '1' then
            -- We've written the request to the SPI Slave. now wait for response
            wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_STATUS));
            wbus_we_o   <= '0';
            wbus_cyc_o  <= '1';
            wbus_stb_o  <= '1';
            state       <= SPI_WAIT_READ_FIFO_ST;
          end if;

        when SPI_WAIT_READ_FIFO_ST =>
          if wbus_ack_i = '1' then
            -- We've read from the SPI Master status register
            if wbus_rddat_i(5) = '0' then
              -- Read FIFO not empty, read response from SPI Slave
              wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_DATA));
              wbus_we_o   <= '0';
              wbus_cyc_o  <= '1';
              wbus_stb_o  <= '1';
              state       <= SPI_READ_DATA_ST;
            else
              -- Read FIFO empty, try again
              wbus_addr_o <= std_logic_vector(unsigned(spi_base_address) + unsigned(C_SPI_STATUS));
              wbus_we_o   <= '0';
              wbus_cyc_o  <= '1';
              wbus_stb_o  <= '1';
              state       <= SPI_WAIT_READ_FIFO_ST;
            end if;
          end if;

        when SPI_READ_DATA_ST =>
          if wbus_ack_i = '1' then
            if ksz_rd_en = '1' then
              -- Result is byte swapped
              ksz_rd_data_o <= wbus_rddat_i(7 downto 0) & wbus_rddat_i(15 downto 8);
              ksz_rd_ack_o  <= '1';
            elsif ksz_wr_en = '1' then
              -- Discard data
              ksz_wr_ack_o <= '1';
            end if;
            state <= IDLE_ST;
          end if;

      end case;

      if state = IDLE_ST then
        timeout_cnt <= 0;
      else
        if timeout_cnt < C_TIMEOUT then
          timeout_cnt <= timeout_cnt + 1;
        else
          -- Abort operation
          wbus_cyc_o <= '0';
          wbus_stb_o <= '0';
          timeout_o  <= '1';
          state      <= IDLE_ST;
        end if;
      end if;

      if rst_i = '1' then
        timeout_cnt  <= 0;
        wr_ack_o     <= '0';
        rd_ack_o     <= '0';
        i_rd_ack_o   <= '0';
        i_wr_ack_o   <= '0';
        ina_rd_ack_o <= '0';
        ina_wr_ack_o <= '0';
        k_rd_ack_o   <= '0';
        k_wr_ack_o   <= '0';
        ksz_rd_ack_o <= '0';
        ksz_wr_ack_o <= '0';
        timeout_o    <= '0';
        wbus_cyc_o   <= '0';
        wbus_stb_o   <= '0';
        wbus_we_o    <= '0';
        state        <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

