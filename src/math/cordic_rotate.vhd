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

  subtype VALUE_TYPE is sfixed(G_BITS - 1 downto -G_ACCURACY);

  signal  s_sign : std_logic;

  signal  shifter_m_valid : std_logic;
  signal  shifter_m_x     : VALUE_TYPE;
  signal  shifter_m_y     : VALUE_TYPE;

  signal  adder_x_s_ready : std_logic;
  signal  adder_x_m_valid : std_logic;

  signal  adder_y_s_ready : std_logic;
  signal  adder_y_m_valid : std_logic;

begin

  sign_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o = '1' and s_valid_i = '1' then
        s_sign <= s_sign_i;
      end if;
    end if;
  end process sign_proc;


  --------------------------------------
  -- Barrel shifter
  --------------------------------------

  shifter_inst : entity work.shifter
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
      m_ready_i => adder_x_s_ready and adder_y_s_ready,
      m_valid_o => shifter_m_valid,
      m_x_o     => shifter_m_x,
      m_y_o     => shifter_m_y
    ); -- shifter_inst : entity work.shifter


  --------------------------------------
  -- (x,y) = (x +- y*coef, y -+ x*coef)
  --------------------------------------

  adder_x_inst : entity work.adder
    generic map (
      G_REG      => true,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s_ready_o    => adder_x_s_ready,
      s_valid_i    => shifter_m_valid,
      s_a_i        => s_x_i,
      s_b_i        => shifter_m_y,
      s_subtract_i => s_sign,
      m_ready_i    => m_ready_i,
      m_valid_o    => adder_x_m_valid,
      m_res_o      => m_x_o
    ); -- adder_sx_inst : entity work.adder

  adder_y_inst : entity work.adder
    generic map (
      G_REG      => true,
      G_BITS     => G_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s_ready_o    => adder_y_s_ready,
      s_valid_i    => shifter_m_valid,
      s_a_i        => s_y_i,
      s_b_i        => shifter_m_x,
      s_subtract_i => not s_sign,
      m_ready_i    => m_ready_i,
      m_valid_o    => adder_y_m_valid,
      m_res_o      => m_y_o
    ); -- adder_sy_inst : entity work.adder

  m_valid_o <= adder_x_m_valid and adder_y_m_valid;

end architecture synthesis;

