library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity shifter is
  generic (
    G_REG      : boolean;
    G_BITS     : natural;
    G_ACCURACY : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_x_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_y_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_shift_i : in    natural;

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_x_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY);
    m_y_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY)
  );
end entity shifter;

architecture synthesis of shifter is

  signal m_x_new : sfixed(G_BITS - 1 downto -G_ACCURACY);
  signal m_y_new : sfixed(G_BITS - 1 downto -G_ACCURACY);

begin

  m_x_new <= resize(s_x_i sra s_shift_i, m_x_o,
                    round_style    => fixed_truncate,
                    overflow_style => fixed_wrap);
  m_y_new <= resize(s_y_i sra s_shift_i, m_y_o,
                    round_style    => fixed_truncate,
                    overflow_style => fixed_wrap);

  reg_gen : if G_REG generate

    s_ready_o <= m_ready_i or not m_valid_o;

    shifter_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if m_ready_i = '1' then
          m_valid_o <= '0';
        end if;

        if s_valid_i = '1' and s_ready_o = '1' then
          m_x_o     <= m_x_new;
          m_y_o     <= m_y_new;
          m_valid_o <= '1';
        end if;

        if rst_i = '1' then
          m_valid_o <= '0';
        end if;
      end if;
    end process shifter_proc;

  else generate
    m_x_o     <= m_x_new;
    m_y_o     <= m_y_new;
  end generate reg_gen;

end architecture synthesis;

