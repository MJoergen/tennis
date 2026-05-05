library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity ball is
  generic (
    G_POS_BITS : natural;
    G_VEL_BITS : natural;
    G_ACCURACY : natural;
    G_SCREEN_X : natural range 0 to 2047;
    G_SCREEN_Y : natural range 0 to 2047
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;
    ce_i         : in    std_logic;
    player_x_i   : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    player_y_i   : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    computer_x_i : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    computer_y_i : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_x_o     : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_y_o     : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY)
  );
end entity ball;

architecture synthesis of ball is

  constant C_GRAVITY : natural  := 1;

  constant C_MAX_POS : natural  := 2047;
  constant C_MAX_VEL : natural  := 100;

  subtype  POS_TYPE is ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
  subtype  VEL_TYPE is sfixed(G_VEL_BITS - 1 downto - G_ACCURACY);

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   m_ready : std_logic;
  signal   m_valid : std_logic;

  signal   pos_x     : POS_TYPE := to_ufixed(G_SCREEN_X / 2, G_POS_BITS - 1, - G_ACCURACY);
  signal   pos_y     : POS_TYPE := to_ufixed(G_SCREEN_Y / 2, G_POS_BITS - 1, - G_ACCURACY);
  signal   vel_x     : VEL_TYPE;
  signal   vel_y     : VEL_TYPE;
  signal   center_x  : POS_TYPE;
  signal   center_y  : POS_TYPE;
  signal   vel_x_new : VEL_TYPE;
  signal   vel_y_new : VEL_TYPE;

begin

  -- Update ball velocity and position
  ball_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if ce_i = '1' then
        vel_x <= vel_x_new;
        vel_y <= resize(vel_y_new + C_GRAVITY, vel_y);

        pos_x <= resize(ufixed(sfixed(pos_x) + vel_x), pos_x);
        pos_y <= resize(ufixed(sfixed(pos_y) + vel_y), pos_y);
      end if;
    end if;
  end process ball_proc;

  -- Check collision with player
  collision_inst : entity work.collision
    generic map (
      G_ACCURACY => G_ACCURACY,
      G_POS_BITS => G_POS_BITS,
      G_VEL_BITS => G_VEL_BITS,
      G_RADIUS   => to_sfixed(8, G_POS_BITS - 1, - G_ACCURACY)
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s_ready_o    => open,
      s_valid_i    => '1',
      s_pos_x_i    => pos_x,
      s_pos_y_i    => pos_y,
      s_vel_x_i    => vel_x,
      s_vel_y_i    => vel_y,
      s_center_x_i => player_x_i,
      s_center_y_i => player_y_i,
      m_ready_i    => ce_i,
      m_valid_o    => open,
      m_vel_x_o    => vel_x_new,
      m_vel_y_o    => vel_y_new
    ); -- collision_inst : entity work.collision

  ball_x_o <= pos_x;
  ball_y_o <= pos_y;

end architecture synthesis;

