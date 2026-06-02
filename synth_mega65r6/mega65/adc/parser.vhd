-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : parser.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Simple command line parser
-- Data is left justified.
-- Commands available:
-- H               : Display help text
-- W AAAA DDDDDDDD : Write <DDDD> to <AAAA>
-- R AAAA          : Read from <AAAA>
-- I               : Read base address of I2C controller
-- I AAAA          : Set base address of I2C controller
-- INA DD RR       : Read from I2C device <DD> address <RR>
-- INA DD RR VVVV  : Write <VVVV> to I2C device <DD> address <RR>
-- K               : Read base address of SPI controller
-- K AAAA          : Set base address of SPI controller
-- KSZ RRRR        : Read from KSZ address <RRRR>
-- KSZ RRRR VVVV   : Write <VVVV> to KSZ address <RRRR>
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity parser is
  generic (
    G_NAME_STR   : string;
    G_DATA_BYTES : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Line buffer
    s_axip_rx_ready_o : out   std_logic;
    s_axip_rx_valid_i : in    std_logic;
    s_axip_rx_data_i  : in    std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    s_axip_rx_bytes_i : in    natural range 0 to G_DATA_BYTES;
    m_axip_tx_ready_i : in    std_logic;
    m_axip_tx_valid_o : out   std_logic;
    m_axip_tx_data_o  : out   std_logic_vector(8 * G_DATA_BYTES - 1 downto 0);
    m_axip_tx_bytes_o : out   natural range 0 to G_DATA_BYTES;

    busy_i            : in    std_logic;
    timeout_i         : in    std_logic;
    wr_addr_o         : out   std_logic_vector(15 downto 0);
    wr_data_o         : out   std_logic_vector(31 downto 0);
    wr_en_o           : out   std_logic;
    wr_ack_i          : in    std_logic;
    rd_addr_o         : out   std_logic_vector(15 downto 0);
    rd_en_o           : out   std_logic;
    rd_data_i         : in    std_logic_vector(31 downto 0);
    rd_ack_i          : in    std_logic;
    i_rd_en_o         : out   std_logic;
    i_rd_addr_i       : in    std_logic_vector(15 downto 0);
    i_rd_ack_i        : in    std_logic;
    i_wr_addr_o       : out   std_logic_vector(15 downto 0);
    i_wr_en_o         : out   std_logic;
    i_wr_ack_i        : in    std_logic;
    ina_rd_device_o   : out   std_logic_vector(7 downto 0);
    ina_rd_register_o : out   std_logic_vector(7 downto 0);
    ina_rd_en_o       : out   std_logic;
    ina_rd_data_i     : in    std_logic_vector(15 downto 0);
    ina_rd_ack_i      : in    std_logic;
    ina_wr_device_o   : out   std_logic_vector(7 downto 0);
    ina_wr_register_o : out   std_logic_vector(7 downto 0);
    ina_wr_data_o     : out   std_logic_vector(15 downto 0);
    ina_wr_en_o       : out   std_logic;
    ina_wr_ack_i      : in    std_logic;
    k_rd_en_o         : out   std_logic;
    k_rd_addr_i       : in    std_logic_vector(15 downto 0);
    k_rd_ack_i        : in    std_logic;
    k_wr_addr_o       : out   std_logic_vector(15 downto 0);
    k_wr_en_o         : out   std_logic;
    k_wr_ack_i        : in    std_logic;
    ksz_rd_register_o : out   std_logic_vector(15 downto 0);
    ksz_rd_en_o       : out   std_logic;
    ksz_rd_data_i     : in    std_logic_vector(15 downto 0);
    ksz_rd_ack_i      : in    std_logic;
    ksz_wr_register_o : out   std_logic_vector(15 downto 0);
    ksz_wr_data_o     : out   std_logic_vector(15 downto 0);
    ksz_wr_en_o       : out   std_logic;
    ksz_wr_ack_i      : in    std_logic
  );
end entity parser;

architecture synthesis of parser is

  constant C_ADDR_CHARS : natural                                         := 4;

  -- Convert ASCII string to std_logic_vector

  pure function str2slv (
    str : string;
    str_len : natural;
    buf_len : natural
  ) return std_logic_vector is
    variable res_v : std_logic_vector(buf_len * 8 - 1 downto 0) := (others => '0');
  begin
    --
    for i in 1 to buf_len loop
      if i <= str'length and i <= str_len then
        res_v(8 * (buf_len - i) + 7 downto 8 * (buf_len - i)) := std_logic_vector(to_unsigned(character'pos(str(i)), 8));
      end if;
    end loop;

    return res_v;
  end function str2slv;

  constant C_CRLF : string(1 to 2)                                        := "" & character'val(13) & character'val(10);

  constant C_START_STR  : string                                          := C_CRLF & G_NAME_STR & C_CRLF;
  constant C_START_DATA : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0) := str2slv(C_START_STR, C_START_STR'length, G_DATA_BYTES);
  constant C_START_SIZE : natural                                         := C_START_STR'length;

  constant C_WHAT_STR  : string                                           := C_CRLF & "WHAT?" & C_CRLF;
  constant C_WHAT_DATA : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0)  := str2slv(C_WHAT_STR, C_WHAT_STR'length, G_DATA_BYTES);
  constant C_WHAT_SIZE : natural                                          := C_WHAT_STR'length;

  constant C_NACK_STR  : string                                           := C_CRLF & "NACK!" & C_CRLF;
  constant C_NACK_DATA : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0)  := str2slv(C_NACK_STR, C_NACK_STR'length, G_DATA_BYTES);
  constant C_NACK_SIZE : natural                                          := C_NACK_STR'length;

  constant C_OK_STR  : string                                             := C_CRLF & "OK" & C_CRLF;
  constant C_OK_DATA : std_logic_vector(8 * G_DATA_BYTES - 1 downto 0)    := str2slv(C_OK_STR, C_OK_STR'length, G_DATA_BYTES);
  constant C_OK_SIZE : natural                                            := C_OK_STR'length;

  type     str_type is record
    str : string(1 to G_DATA_BYTES);
    len : natural range 0 to G_DATA_BYTES;
  end record str_type;

  pure function to_str_type (
    arg  : string
  ) return str_type is
    variable res_v : str_type;
  begin
    res_v.len            := arg'length;
    res_v.str            := (others => ' ');
    res_v.str(arg'range) := arg;
    return res_v;
  end function to_str_type;

  type     str_vector_type is array (natural range <>) of str_type;

  constant C_HELP_STR    : str_vector_type(0 to 11)                       :=
  (
    to_str_type("" & C_CRLF),
    to_str_type("H" & C_CRLF),
    to_str_type("W AAAA DDDDDDDD" & C_CRLF),
    to_str_type("R AAAA" & C_CRLF),
    to_str_type("I" & C_CRLF),
    to_str_type("I AAAA" & C_CRLF),
    to_str_type("INA DD RR" & C_CRLF),
    to_str_type("INA DD RR VVVV" & C_CRLF),
    to_str_type("K" & C_CRLF),
    to_str_type("K AAAA" & C_CRLF),
    to_str_type("KSZ RRRR" & C_CRLF),
    to_str_type("KSZ RRRR VVVV" & C_CRLF)
  );
  signal   help_str_line : natural range C_HELP_STR'range;

  type     state_type is (
    START_ST, IDLE_ST, HELP_ST, WR_ST, RD_ST, I_RD_ST, I_WR_ST, INA_RD_ST, INA_WR_ST,
    K_RD_ST, K_WR_ST, KSZ_RD_ST, KSZ_WR_ST
  );
  signal   state : state_type                                             := START_ST;

  subtype  R_BYTE1 is natural range G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8;

  subtype  R_BYTES1_2 is natural range G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 16;

  subtype  R_BYTES1_3 is natural range G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 24;

  subtype  R_BYTES1_4 is natural range G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 32;

  subtype  R_BYTES3_6 is natural range G_DATA_BYTES * 8 - 17 downto G_DATA_BYTES * 8 - 48;

  subtype  R_BYTES3_10 is natural range G_DATA_BYTES * 8 - 17 downto G_DATA_BYTES * 8 - 80;

  subtype  R_BYTES5_6 is natural range G_DATA_BYTES * 8 - 33 downto G_DATA_BYTES * 8 - 48;

  subtype  R_BYTES5_8 is natural range G_DATA_BYTES * 8 - 33 downto G_DATA_BYTES * 8 - 64;

  subtype  R_BYTE7 is natural range G_DATA_BYTES * 8 - 49 downto G_DATA_BYTES * 8 - 56;

  subtype  R_BYTES7_8 is natural range G_DATA_BYTES * 8 - 49 downto G_DATA_BYTES * 8 - 64;

  subtype  R_BYTES8_9 is natural range G_DATA_BYTES * 8 - 57 downto G_DATA_BYTES * 8 - 72;

  subtype  R_BYTES8_15 is natural range G_DATA_BYTES * 8 - 57 downto G_DATA_BYTES * 8 - 120;

  subtype  R_BYTE9 is natural range G_DATA_BYTES * 8 - 65 downto G_DATA_BYTES * 8 - 72;

  subtype  R_BYTE10 is natural range G_DATA_BYTES * 8 - 73 downto G_DATA_BYTES * 8 - 80;

  subtype  R_BYTES10_13 is natural range G_DATA_BYTES * 8 - 73 downto G_DATA_BYTES * 8 - 104;

  subtype  R_BYTES11_12 is natural range G_DATA_BYTES * 8 - 81 downto G_DATA_BYTES * 8 - 96;

  subtype  R_BYTES11_14 is natural range G_DATA_BYTES * 8 - 81 downto G_DATA_BYTES * 8 - 112;

  -- Detect whether a std_logic_vector represents a valid ASCII hexadecimal string.

  pure function is_hex (
    arg : std_logic_vector
  ) return boolean is
    variable hex_v : unsigned(7 downto 0);
  begin
    for i in 0 to arg'length / 8 - 1 loop
      hex_v := unsigned(arg(8 * i + 7 + arg'right downto 8 * i + arg'right));
      if not ((hex_v >= X"30" and hex_v <= X"39") or
              (hex_v >= X"41" and hex_v <= X"46") or
              (hex_v >= X"61" and hex_v <= X"66")) then
        return false;
      end if;
    end loop;

    return true;
  end function is_hex;

  -- Convert an ASCII hexadecimal string (in a std_logic_vector) to a std_logic_vector.

  pure function asc2slv (
    arg : std_logic_vector
  ) return std_logic_vector is
    variable hex_v : std_logic_vector(7 downto 0);
    variable ret_v : std_logic_vector(arg'length / 2 - 1 downto 0);
  begin
    --
    for i in 0 to arg'length / 8 - 1 loop
      hex_v := arg(8 * i + 7 + arg'right downto 8 * i + arg'right);

      case hex_v(7 downto 4) is

        when "0011" =>
          ret_v(4 * i + 3 downto 4 * i) := hex_v(3 downto 0);

        when "0100" | "0110" =>
          ret_v(4 * i + 3 downto 4 * i) := std_logic_vector(unsigned(hex_v(3 downto 0)) + "1001");

        when others =>
          null;

      end case;

    --
    end loop;

    return ret_v;
  end function asc2slv;

  -- Convert a std_logic_vector to an ASCII hexadecimal string (in a std_logic_vector).

  pure function slv2asc (
    arg : std_logic_vector
  ) return std_logic_vector is
    variable hex_v : std_logic_vector(3 downto 0);
    variable ret_v : std_logic_vector(arg'length * 2 - 1 downto 0);
  begin
    --
    for i in 0 to arg'length / 4 - 1 loop
      hex_v := arg(4 * i + 3 downto 4 * i);
      if unsigned(hex_v) < "1010" then
        ret_v(8 * i + 7 downto 8 * i) := std_logic_vector(X"30" + unsigned(hex_v));
      else
        ret_v(8 * i + 7 downto 8 * i) := std_logic_vector(X"41" + unsigned(hex_v) - 10);
      end if;
    end loop;

    return ret_v;
  end function slv2asc;

begin

  s_axip_rx_ready_o <= '1' when state = IDLE_ST and
                                m_axip_tx_valid_o = '0' and
                                busy_i = '0' else
                       '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axip_tx_ready_i = '1' then
        m_axip_tx_data_o  <= (others => '0');
        m_axip_tx_valid_o <= '0';
      end if;

      wr_en_o     <= '0';
      rd_en_o     <= '0';
      i_rd_en_o   <= '0';
      i_wr_en_o   <= '0';
      ina_rd_en_o <= '0';
      ina_wr_en_o <= '0';
      k_rd_en_o   <= '0';
      k_wr_en_o   <= '0';
      ksz_rd_en_o <= '0';
      ksz_wr_en_o <= '0';

      case state is

        when START_ST =>
          m_axip_tx_bytes_o <= C_START_SIZE;
          m_axip_tx_data_o  <= C_START_DATA;
          m_axip_tx_valid_o <= '1';
          state             <= IDLE_ST;

        when IDLE_ST =>
          if s_axip_rx_valid_i = '1' and s_axip_rx_ready_o = '1' then
            -- Default response
            m_axip_tx_bytes_o <= C_WHAT_SIZE;
            m_axip_tx_data_o  <= C_WHAT_DATA;
            m_axip_tx_valid_o <= '1';

            -- Parse input string
            case s_axip_rx_bytes_i is

              when 1 =>
                if s_axip_rx_data_i(R_BYTE1) = X"48" or
                   s_axip_rx_data_i(R_BYTE1) = X"68" then
                  -- "H"
                  help_str_line     <= 0;
                  m_axip_tx_bytes_o <= C_START_SIZE;
                  m_axip_tx_data_o  <= C_START_DATA;
                  m_axip_tx_valid_o <= '1';
                  state             <= HELP_ST;
                elsif s_axip_rx_data_i(R_BYTE1) = X"49" or
                      s_axip_rx_data_i(R_BYTE1) = X"69" then
                  -- "I"
                  i_rd_en_o         <= '1';
                  state             <= I_RD_ST;
                  m_axip_tx_valid_o <= '0';
                elsif s_axip_rx_data_i(R_BYTE1) = X"4B" or
                      s_axip_rx_data_i(R_BYTE1) = X"6B" then
                  -- "K"
                  k_rd_en_o         <= '1';
                  state             <= K_RD_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 6 =>
                if (s_axip_rx_data_i(R_BYTES1_2) = X"5220" or
                    s_axip_rx_data_i(R_BYTES1_2) = X"7220") and
                   is_hex(s_axip_rx_data_i(R_BYTES3_6)) then
                  -- "R AAAA"
                  rd_addr_o         <= asc2slv(s_axip_rx_data_i(R_BYTES3_6));
                  rd_en_o           <= '1';
                  state             <= RD_ST;
                  m_axip_tx_valid_o <= '0';
                elsif (s_axip_rx_data_i(R_BYTES1_2) = X"4920" or
                       s_axip_rx_data_i(R_BYTES1_2) = X"6920") and
                      is_hex(s_axip_rx_data_i(R_BYTES3_6)) then
                  -- "I AAAA"
                  i_wr_addr_o       <= asc2slv(s_axip_rx_data_i(R_BYTES3_6));
                  i_wr_en_o         <= '1';
                  state             <= I_WR_ST;
                  m_axip_tx_valid_o <= '0';
                elsif (s_axip_rx_data_i(R_BYTES1_2) = X"4B20" or
                       s_axip_rx_data_i(R_BYTES1_2) = X"6B20") and
                      is_hex(s_axip_rx_data_i(R_BYTES3_6)) then
                  -- "K AAAA"
                  k_wr_addr_o       <= asc2slv(s_axip_rx_data_i(R_BYTES3_6));
                  k_wr_en_o         <= '1';
                  state             <= K_WR_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 8 =>
                if (s_axip_rx_data_i(R_BYTES1_4) = X"4B535A20" or
                    s_axip_rx_data_i(R_BYTES1_4) = X"6B737A20") and
                   is_hex(s_axip_rx_data_i(R_BYTES5_8)) then
                  -- "KSZ RRRR"
                  ksz_rd_register_o <= asc2slv(s_axip_rx_data_i(R_BYTES5_8));
                  ksz_rd_en_o       <= '1';
                  state             <= KSZ_RD_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 9 =>
                if (s_axip_rx_data_i(R_BYTES1_4) = X"494E4120" or
                    s_axip_rx_data_i(R_BYTES1_4) = X"696E6120") and
                   is_hex(s_axip_rx_data_i(R_BYTES5_6)) and
                   s_axip_rx_data_i(R_BYTE7) = X"20" and
                   is_hex(s_axip_rx_data_i(R_BYTES8_9)) then
                  -- "INA DD RR"
                  ina_rd_device_o   <= asc2slv(s_axip_rx_data_i(R_BYTES5_6));
                  ina_rd_register_o <= asc2slv(s_axip_rx_data_i(R_BYTES8_9));
                  ina_rd_en_o       <= '1';
                  state             <= INA_RD_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 13 =>
                if (s_axip_rx_data_i(R_BYTES1_4) = X"4B535A20" or
                    s_axip_rx_data_i(R_BYTES1_4) = X"6B737A20") and
                   is_hex(s_axip_rx_data_i(R_BYTES5_8)) and
                   s_axip_rx_data_i(R_BYTE9) = X"20" and
                   is_hex(s_axip_rx_data_i(R_BYTES10_13)) then
                  -- "KSZ RRRR VVVV"
                  ksz_wr_register_o <= asc2slv(s_axip_rx_data_i(R_BYTES5_8));
                  ksz_wr_data_o     <= asc2slv(s_axip_rx_data_i(R_BYTES10_13));
                  ksz_wr_en_o       <= '1';
                  state             <= KSZ_WR_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 14 =>
                if (s_axip_rx_data_i(R_BYTES1_4) = X"494E4120" or
                    s_axip_rx_data_i(R_BYTES1_4) = X"696E6120") and
                   is_hex(s_axip_rx_data_i(R_BYTES5_6)) and
                   s_axip_rx_data_i(R_BYTE7) = X"20" and
                   is_hex(s_axip_rx_data_i(R_BYTES8_9)) and
                   s_axip_rx_data_i(R_BYTE10) = X"20" and
                   is_hex(s_axip_rx_data_i(R_BYTES11_14)) then
                  -- "INA DD RR VVVV"
                  ina_wr_device_o   <= asc2slv(s_axip_rx_data_i(R_BYTES5_6));
                  ina_wr_register_o <= asc2slv(s_axip_rx_data_i(R_BYTES8_9));
                  ina_wr_data_o     <= asc2slv(s_axip_rx_data_i(R_BYTES11_14));
                  ina_wr_en_o       <= '1';
                  state             <= INA_WR_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when 15 =>
                if (s_axip_rx_data_i(R_BYTES1_2) = X"5720" or
                    s_axip_rx_data_i(R_BYTES1_2) = X"7720") and
                   is_hex(s_axip_rx_data_i(R_BYTES3_6)) and
                   s_axip_rx_data_i(R_BYTE7) = X"20" and
                   is_hex(s_axip_rx_data_i(R_BYTES8_15)) then
                  -- "W AAAA DDDDDDDD"
                  wr_addr_o         <= asc2slv(s_axip_rx_data_i(R_BYTES3_6));
                  wr_data_o         <= asc2slv(s_axip_rx_data_i(R_BYTES8_15));
                  wr_en_o           <= '1';
                  state             <= WR_ST;
                  m_axip_tx_valid_o <= '0';
                end if;

              when others =>
                null;

            end case;

          end if;

        when HELP_ST =>
          if m_axip_tx_valid_o = '0' then
            m_axip_tx_bytes_o <= C_HELP_STR(help_str_line).len;
            m_axip_tx_data_o  <= str2slv(C_HELP_STR(help_str_line).str,
                                         C_HELP_STR(help_str_line).len, G_DATA_BYTES);
            m_axip_tx_valid_o <= '1';

            if help_str_line >= C_HELP_STR'high then
              state <= IDLE_ST;
            else
              help_str_line <= help_str_line + 1;
            end if;
          end if;

        when WR_ST =>
          if wr_ack_i = '1' then
            m_axip_tx_bytes_o <= C_OK_SIZE;
            m_axip_tx_data_o  <= C_OK_DATA;
            m_axip_tx_valid_o <= '1';
            state             <= IDLE_ST;
          end if;

        when RD_ST =>
          if rd_ack_i = '1' then
            m_axip_tx_bytes_o              <= 12;
            m_axip_tx_data_o(R_BYTES1_2)   <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_data_o(R_BYTES3_10)  <= slv2asc(rd_data_i);
            m_axip_tx_data_o(R_BYTES11_12) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_valid_o              <= '1';
            state                          <= IDLE_ST;
          end if;

        when I_RD_ST =>
          if i_rd_ack_i = '1' then
            m_axip_tx_bytes_o            <= 8;
            m_axip_tx_data_o(R_BYTES1_2) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_data_o(R_BYTES3_6) <= slv2asc(i_rd_addr_i);
            m_axip_tx_data_o(R_BYTES7_8) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_valid_o            <= '1';
            state                        <= IDLE_ST;
          end if;

        when I_WR_ST =>
          if i_wr_ack_i = '1' then
            m_axip_tx_bytes_o <= C_OK_SIZE;
            m_axip_tx_data_o  <= C_OK_DATA;
            m_axip_tx_valid_o <= '1';
            state             <= IDLE_ST;
          end if;

        when INA_RD_ST =>
          if ina_rd_ack_i = '1' then
            m_axip_tx_bytes_o            <= 8;
            m_axip_tx_data_o(R_BYTES1_2) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_data_o(R_BYTES3_6) <= slv2asc(ina_rd_data_i);
            m_axip_tx_data_o(R_BYTES7_8) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_valid_o            <= '1';
            state                        <= IDLE_ST;
          end if;

        when INA_WR_ST =>
          if ina_wr_ack_i = '1' then
            m_axip_tx_bytes_o <= C_OK_SIZE;
            m_axip_tx_data_o  <= C_OK_DATA;
            m_axip_tx_valid_o <= '1';
            state             <= IDLE_ST;
          end if;

        when K_RD_ST =>
          if k_rd_ack_i = '1' then
            m_axip_tx_bytes_o            <= 8;
            m_axip_tx_data_o(R_BYTES1_2) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_data_o(R_BYTES3_6) <= slv2asc(k_rd_addr_i);
            m_axip_tx_data_o(R_BYTES7_8) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_valid_o            <= '1';
            state                        <= IDLE_ST;
          end if;

        when K_WR_ST =>
          if k_wr_ack_i = '1' then
            m_axip_tx_bytes_o <= C_OK_SIZE;
            m_axip_tx_data_o  <= C_OK_DATA;
            m_axip_tx_valid_o <= '1';
            state             <= IDLE_ST;
          end if;

        when KSZ_RD_ST =>
          if ksz_rd_ack_i = '1' then
            m_axip_tx_bytes_o            <= 8;
            m_axip_tx_data_o(R_BYTES1_2) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_data_o(R_BYTES3_6) <= slv2asc(ksz_rd_data_i);
            m_axip_tx_data_o(R_BYTES7_8) <= str2slv(C_CRLF, 2, 2);
            m_axip_tx_valid_o            <= '1';
            state                        <= IDLE_ST;
          end if;

        when KSZ_WR_ST =>
          if ksz_wr_ack_i = '1' then
            m_axip_tx_bytes_o <= C_OK_SIZE;
            m_axip_tx_data_o  <= C_OK_DATA;
            m_axip_tx_valid_o <= '1';
            state             <= IDLE_ST;
          end if;

      end case;

      if timeout_i = '1' then
        m_axip_tx_bytes_o <= C_NACK_SIZE;
        m_axip_tx_data_o  <= C_NACK_DATA;
        m_axip_tx_valid_o <= '1';
        state             <= IDLE_ST;
      end if;

      if rst_i = '1' then
        wr_en_o           <= '0';
        rd_en_o           <= '0';
        i_rd_en_o         <= '0';
        i_wr_en_o         <= '0';
        ina_rd_en_o       <= '0';
        ina_wr_en_o       <= '0';
        k_rd_en_o         <= '0';
        k_wr_en_o         <= '0';
        ksz_rd_en_o       <= '0';
        ksz_wr_en_o       <= '0';
        m_axip_tx_valid_o <= '0';
        state             <= START_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

