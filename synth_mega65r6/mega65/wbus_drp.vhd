-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : wbus_drp.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_drp is
  generic (
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    -- Clock and Reset
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    wbus_cyc_i   : in    std_logic;
    wbus_stall_o : out   std_logic;
    wbus_stb_i   : in    std_logic;
    wbus_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    wbus_we_i    : in    std_logic;
    wbus_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    wbus_ack_o   : out   std_logic;
    wbus_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    drp_addr_o   : out   std_logic_vector(8 downto 0);
    drp_en_o     : out   std_logic;
    drp_di_o     : out   std_logic_vector(15 downto 0);
    drp_we_o     : out   std_logic;
    drp_do_i     : in    std_logic_vector(15 downto 0);
    drp_rdy_i    : in    std_logic
  );
end entity wbus_drp;

architecture synthesis of wbus_drp is

  type   state_type is (IDLE_ST, BUSY_ST);
  signal state : state_type := IDLE_ST;

begin

  wbus_stall_o <= '0' when state = IDLE_ST else
                  '1';

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      drp_en_o   <= '0';
      wbus_ack_o <= '0';

      case state is

        when IDLE_ST =>
          if wbus_cyc_i = '1' and wbus_stb_i = '1' and wbus_ack_o = '0' then
            drp_en_o   <= '1';
            drp_addr_o <= wbus_addr_i(10 downto 2);
            drp_di_o   <= wbus_wrdat_i(15 downto 0);
            drp_we_o   <= wbus_we_i;
            state      <= BUSY_ST;
          end if;

        when BUSY_ST =>
          if drp_rdy_i = '1' then
            wbus_rddat_o(15 downto 0) <= drp_do_i;
            wbus_ack_o                <= '1';
            state                     <= IDLE_ST;
          end if;

      end case;

      if wbus_cyc_i = '0' or rst_i = '1' then
        drp_en_o   <= '0';
        wbus_ack_o <= '0';
        state      <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

