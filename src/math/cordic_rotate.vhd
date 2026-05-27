library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity cordic_rotate is
  generic (
    G_ACCURACY : natural;
    G_BITS     : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_x_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_y_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_shift_i : in    natural;
    s_sign_i  : in    std_logic;

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_x_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY);
    m_y_o     : out   sfixed(G_BITS - 1 downto -G_ACCURACY)
  );
end entity cordic_rotate;

architecture synthesis of cordic_rotate is

  subtype INPUT_TYPE is sfixed(G_BITS - 1 downto -G_ACCURACY);

  signal  s_sign : std_logic;

  signal  shifter_m_x : INPUT_TYPE;
  signal  shifter_m_y : INPUT_TYPE;

  signal  inc_x : INPUT_TYPE;
  signal  inc_y : INPUT_TYPE;

begin

  sign_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o = '1' and s_valid_i = '1' then
        s_sign <= s_sign_i;
      end if;
    end if;
  end process sign_proc;

  shifter_s_inst : entity work.shifter
    generic map (
      G_REG      => true,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_x_i     => s_x_i,
      s_y_i     => s_y_i,
      s_shift_i => s_shift_i,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_x_o     => shifter_m_x,
      m_y_o     => shifter_m_y
    ); -- shifter_s_inst : entity work.shifter

  -- (x,y) = (x +- y*coef, y -+ x*coef)
  inc_x <= shifter_m_y when s_sign = '0' else
           resize(-shifter_m_y, inc_x,
                   round_style    => fixed_truncate,
                   overflow_style => fixed_wrap);

  inc_y <= resize(-shifter_m_x, inc_y,
                   round_style    => fixed_truncate,
                   overflow_style => fixed_wrap) when s_sign_i = '0' else
           shifter_m_x;

  adder_sx_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => s_x_i,
      s_b_i     => inc_x,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => m_x_o
    ); -- adder_sx_inst : entity work.adder

  adder_sy_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i     => '0',
      rst_i     => '0',
      s_ready_o => open,
      s_valid_i => '1',
      s_a_i     => s_y_i,
      s_b_i     => inc_y,
      m_ready_i => '1',
      m_valid_o => open,
      m_res_o   => m_y_o
    ); -- adder_sy_inst : entity work.adder

end architecture synthesis;

