-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : line_buffer.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Serial to Parallel and back.
-- Data is left-justified.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity line_buffer is
  generic (
    G_LOCAL_ECHO : boolean;
    G_DATA_BYTES : positive
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- AXI streaming interface
    s_axis_rx_ready_o : out   std_logic;
    s_axis_rx_valid_i : in    std_logic;
    s_axis_rx_data_i  : in    std_logic_vector(7 downto 0);

    m_axis_tx_ready_i : in    std_logic;
    m_axis_tx_valid_o : out   std_logic;
    m_axis_tx_data_o  : out   std_logic_vector(7 downto 0);

    -- AXI packet interface
    m_axip_rx_ready_i : in    std_logic;
    m_axip_rx_valid_o : out   std_logic;
    m_axip_rx_data_o  : out   std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    m_axip_rx_bytes_o : out   natural range 0 to G_DATA_BYTES;

    s_axip_tx_ready_o : out   std_logic;
    s_axip_tx_valid_i : in    std_logic;
    s_axip_tx_data_i  : in    std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    s_axip_tx_bytes_i : in    natural range 0 to G_DATA_BYTES
  );
end entity line_buffer;

architecture synthesis of line_buffer is

  constant C_NULL      : std_logic_vector(7 downto 0)  := X"00";
  constant C_CR        : std_logic_vector(7 downto 0)  := X"0D";
  constant C_LF        : std_logic_vector(7 downto 0)  := X"0A";
  constant C_CTRL_C    : std_logic_vector(7 downto 0)  := X"03";
  constant C_UP_ARROW  : std_logic_vector(23 downto 0) := X"1B5B41";
  constant C_BACKSPACE : std_logic_vector(7 downto 0)  := X"7F";


  -- AXI streaming to AXI packet
  type     rx_state_type is (RECEIVING_ST, PROCESSING_ST);
  signal   rx_state : rx_state_type                    := RECEIVING_ST;

  signal   stored_size : natural range 0 to G_DATA_BYTES;
  signal   stored_data : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);


  -- AXI packet to AXI streaming
  type     tx_state_type is (IDLE_ST, SENDING_ST);
  signal   tx_state : tx_state_type                    := IDLE_ST;

  signal   tx_data  : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
  signal   tx_bytes : natural range 0 to G_DATA_BYTES;

begin

  ----------------------------------------------------------
  -- AXI streaming to AXI packet
  ----------------------------------------------------------

  s_axis_rx_ready_o <= '1' when rx_state = RECEIVING_ST and
                                (m_axis_tx_valid_o = '0' or not G_LOCAL_ECHO) else
                       '0';

  rx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case rx_state is

        when RECEIVING_ST =>
          if s_axis_rx_valid_i = '1' and s_axis_rx_ready_o = '1' then

            case s_axis_rx_data_i is

              when C_BACKSPACE =>
                -- Delete last character
                if m_axip_rx_bytes_o > 0 then
                  m_axip_rx_bytes_o <= m_axip_rx_bytes_o - 1;
                end if;

              when C_CTRL_C =>
                -- Clear line
                m_axip_rx_bytes_o <= 0;

              when C_CR | C_LF =>
                if m_axip_rx_bytes_o /= 0 then
                  m_axip_rx_valid_o <= '1';
                  rx_state          <= PROCESSING_ST;
                end if;

              when others =>
                if s_axis_rx_data_i = C_UP_ARROW(7 downto 0) and
                   m_axip_rx_bytes_o = 2 and
                   m_axip_rx_data_o(8 * G_DATA_BYTES - 1 downto 8 * G_DATA_BYTES - 16) =
                   C_UP_ARROW(23 downto 8) then
                  -- User pressed "up arrow"
                  m_axip_rx_data_o  <= stored_data;
                  m_axip_rx_bytes_o <= stored_size;
                else
                  m_axip_rx_data_o(8 * G_DATA_BYTES - 8 * m_axip_rx_bytes_o - 1  downto
                  8 * G_DATA_BYTES - 8 * m_axip_rx_bytes_o - 8) <= s_axis_rx_data_i;
                  m_axip_rx_bytes_o                             <= m_axip_rx_bytes_o + 1;
                  if m_axip_rx_bytes_o = G_DATA_BYTES - 1 then
                    m_axip_rx_valid_o <= '1';
                    rx_state          <= PROCESSING_ST;
                  end if;
                end if;

            end case;

          end if;

        when PROCESSING_ST =>
          stored_data <= m_axip_rx_data_o;
          stored_size <= m_axip_rx_bytes_o;

          if m_axip_rx_ready_i = '1' then
            m_axip_rx_valid_o <= '0';
            m_axip_rx_bytes_o <= 0;
            rx_state          <= RECEIVING_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_axip_rx_valid_o <= '0';
        m_axip_rx_bytes_o <= 0;
        rx_state          <= RECEIVING_ST;
        stored_size       <= 0;
      end if;
    end if;
  end process rx_proc;


  ----------------------------------------------------------
  -- AXI packet to AXI streaming
  ----------------------------------------------------------

  s_axip_tx_ready_o <= '1' when tx_state = IDLE_ST and
                                (s_axis_rx_valid_i = '0' or not G_LOCAL_ECHO) and
                                m_axis_tx_valid_o = '0' else
                       '0';

  tx_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axis_tx_ready_i = '1' then
        m_axis_tx_valid_o <= '0';
      end if;

      case tx_state is

        when IDLE_ST =>
          if s_axis_rx_valid_i = '1' and s_axis_rx_ready_o = '1' and G_LOCAL_ECHO then
            -- Handle local echo
            m_axis_tx_data_o  <= s_axis_rx_data_i;
            m_axis_tx_valid_o <= '1';
            if s_axis_rx_data_i = C_CTRL_C then
              m_axis_tx_data_o                                          <= C_CR; -- Start new line
              m_axis_tx_valid_o                                         <= '1';
              tx_data(8 * G_DATA_BYTES - 1 downto 8 * G_DATA_BYTES - 8) <= C_LF;
              tx_bytes                                                  <= 1;
              tx_state                                                  <= SENDING_ST;
            elsif s_axis_rx_data_i = C_UP_ARROW(7 downto 0) and
                  m_axip_rx_bytes_o = 2 and
                  m_axip_rx_data_o(8 * G_DATA_BYTES - 1 downto 8 * G_DATA_BYTES - 16) =
                  C_UP_ARROW(23 downto 8) then
              -- User pressed "up arrow"
              tx_data  <= C_LF & stored_data(8 * G_DATA_BYTES - 1 downto 8);
              tx_bytes <= stored_size + 1;
              tx_state <= SENDING_ST;
            end if;
          elsif s_axip_tx_valid_i = '1' and s_axip_tx_ready_o = '1' then
            if s_axip_tx_bytes_i /= 0 then
              tx_data           <= s_axip_tx_data_i(8 * G_DATA_BYTES - 9 downto 0) & X"00";
              tx_bytes          <= s_axip_tx_bytes_i - 1;
              m_axis_tx_data_o  <= s_axip_tx_data_i(8 * G_DATA_BYTES - 1 downto 8 *
                                                    G_DATA_BYTES - 8);
              m_axis_tx_valid_o <= '1';
              tx_state          <= SENDING_ST;
            end if;
          end if;

        when SENDING_ST =>
          if m_axis_tx_ready_i = '1' then
            if tx_bytes /= 0 then
              tx_data           <= tx_data(8 * G_DATA_BYTES - 9 downto 0) & X"00";
              m_axis_tx_data_o  <= tx_data(8 * G_DATA_BYTES - 1 downto 8 *
                                           G_DATA_BYTES - 8);
              m_axis_tx_valid_o <= '1';
              tx_bytes          <= tx_bytes - 1;
            else
              tx_state <= IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        tx_state          <= IDLE_ST;
        m_axis_tx_valid_o <= '0';
      end if;
    end if;
  end process tx_proc;

end architecture synthesis;

