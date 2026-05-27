library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity ball is
  generic (
    G_RADIUS   : natural;
    G_POS_BITS : natural;
    G_VEL_BITS : natural;
    G_ACCURACY : natural;
    G_GRAVITY  : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
    G_SCREEN_X : natural range 0 to 4095;
    G_SCREEN_Y : natural range 0 to 4095
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;
    ce_i         : in    std_logic;
    player_x_i   : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    player_y_i   : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    computer_x_i : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    computer_y_i : in    ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_pos_x_o : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_pos_y_o : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_vel_x_o : out   sfixed(G_VEL_BITS - 1 downto - G_ACCURACY);
    ball_vel_y_o : out   sfixed(G_VEL_BITS - 1 downto - G_ACCURACY);
    ball_valid_o : out   std_logic
  );
end entity ball;

architecture synthesis of ball is

  type   state_type is (IDLE_ST, PLAYER_ST, COMPUTER_ST, LEFT_WALL_ST);
  signal state : state_type                                             := IDLE_ST;

  signal s_pos_x : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal s_pos_y : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal s_vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal s_vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal disk_s_ready      : std_logic;
  signal disk_s_valid      : std_logic;
  signal disk_s_a_pos_x    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal disk_s_a_pos_y    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal disk_s_a_vel_x    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal disk_s_a_vel_y    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal disk_s_a_radius   : ufixed(G_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(G_RADIUS, G_POS_BITS - 1, - G_ACCURACY);
  signal disk_s_b_center_x : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal disk_s_b_center_y : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal disk_s_b_radius   : ufixed(G_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(G_RADIUS, G_POS_BITS - 1, - G_ACCURACY);
  signal disk_m_valid      : std_logic;
  signal disk_m_vel_x      : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal disk_m_vel_y      : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal line_s_ready      : std_logic;
  signal line_s_valid      : std_logic;
  signal line_s_a_pos_x    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal line_s_a_pos_y    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal line_s_a_vel_x    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal line_s_a_vel_y    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal line_s_a_radius   : ufixed(G_POS_BITS - 1 downto 0)            := to_ufixed(G_RADIUS, G_POS_BITS - 1, 0);
  signal line_s_b_point_x  : ufixed(G_POS_BITS - 1 downto 0);
  signal line_s_b_point_y  : ufixed(G_POS_BITS - 1 downto 0);
  signal line_s_b_normal_x : sfixed(1 downto -G_ACCURACY);
  signal line_s_b_normal_y : sfixed(1 downto -G_ACCURACY);
  signal line_m_valid      : std_logic;
  signal line_m_vel_x      : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal line_m_vel_y      : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

  signal s_pos_x_new : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal s_pos_y_new : sfixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal s_vel_y_new : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

begin

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if disk_s_ready = '1' then
        disk_s_valid <= '0';
      end if;
      if line_s_ready = '1' then
        line_s_valid <= '0';
      end if;
      ball_valid_o <= '0';

      case state is

        when IDLE_ST =>
          if ce_i = '1' then
            disk_s_a_pos_x    <= s_pos_x;
            disk_s_a_pos_y    <= s_pos_y;
            disk_s_a_vel_x    <= s_vel_x;
            disk_s_a_vel_y    <= s_vel_y;
            disk_s_b_center_x <= player_x_i;
            disk_s_b_center_y <= player_y_i;
            disk_s_valid      <= '1';
            state             <= PLAYER_ST;
          end if;

        when PLAYER_ST =>
          if disk_m_valid = '1' then
            disk_s_a_vel_x    <= disk_m_vel_x;
            disk_s_a_vel_y    <= disk_m_vel_y;
            disk_s_b_center_x <= computer_x_i;
            disk_s_b_center_y <= computer_y_i;
            disk_s_valid      <= '1';
            state             <= COMPUTER_ST;
          end if;

        when COMPUTER_ST =>
          if disk_m_valid = '1' then
            line_s_a_pos_x    <= s_pos_x;
            line_s_a_pos_y    <= s_pos_y;
            line_s_a_vel_x    <= disk_m_vel_x;
            line_s_a_vel_y    <= disk_m_vel_y;
            line_s_b_point_x  <= to_ufixed(G_RADIUS, G_POS_BITS - 1, 0);
            line_s_b_point_y  <= to_ufixed(0, G_POS_BITS - 1, 0);
            line_s_b_normal_x <= to_sfixed(1, 1, -G_ACCURACY);
            line_s_b_normal_y <= to_sfixed(0, 1, -G_ACCURACY);
            line_s_valid      <= '1';
            state             <= LEFT_WALL_ST;
          end if;

        when LEFT_WALL_ST =>
          if line_m_valid = '1' then
            s_vel_x      <= line_m_vel_x;
            s_vel_y      <= s_vel_y_new;
            s_pos_x      <= ufixed(s_pos_x_new);
            s_pos_y      <= ufixed(s_pos_y_new);
            ball_valid_o <= '1';
            state        <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        disk_s_valid <= '0';
        line_s_valid <= '0';
        s_pos_x      <= to_ufixed(G_SCREEN_X / 4, G_POS_BITS - 1, - G_ACCURACY);
        s_pos_y      <= to_ufixed(G_SCREEN_Y / 2, G_POS_BITS - 1, - G_ACCURACY);
        s_vel_x      <= to_sfixed(0, G_VEL_BITS - 1, - G_ACCURACY);
        s_vel_y      <= to_sfixed(0, G_VEL_BITS - 1, - G_ACCURACY);
        state        <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

  -- s_vel_y <= resize(m_vel_y + G_GRAVITY, s_vel_y);
  adder_vel_y_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_VEL_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i        => '0',
      rst_i        => '0',
      s_ready_o    => open,
      s_valid_i    => '0',
      s_a_i        => line_m_vel_y,
      s_b_i        => G_GRAVITY,
      s_subtract_i => '0',
      m_ready_i    => '0',
      m_valid_o    => open,
      m_res_o      => s_vel_y_new
    ); -- adder_vel_y_inst : entity work.adder

  -- s_pos_x <= resize(ufixed(sfixed(s_pos_x) + s_vel_x), s_pos_x);
  adder_pos_x_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_POS_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i        => '0',
      rst_i        => '0',
      s_ready_o    => open,
      s_valid_i    => '0',
      s_a_i        => sfixed(s_pos_x),
      s_b_i        => resize(line_m_vel_x, G_POS_BITS - 1, - G_ACCURACY),
      s_subtract_i => '0',
      m_ready_i    => '0',
      m_valid_o    => open,
      m_res_o      => s_pos_x_new
    ); -- adder_pos_x_inst : entity work.adder

  -- s_pos_y <= resize(ufixed(sfixed(s_pos_y) + s_vel_y), s_pos_y);
  adder_pos_y_inst : entity work.adder
    generic map (
      G_REG      => false,
      G_BITS     => G_POS_BITS,
      G_ACCURACY => G_ACCURACY
    )
    port map (
      clk_i        => '0',
      rst_i        => '0',
      s_ready_o    => open,
      s_valid_i    => '0',
      s_a_i        => sfixed(s_pos_y),
      s_b_i        => resize(line_m_vel_y, G_POS_BITS - 1, - G_ACCURACY),
      s_subtract_i => '0',
      m_ready_i    => '0',
      m_valid_o    => open,
      m_res_o      => s_pos_y_new
    ); -- adder_pos_y_inst : entity work.adder

  -- Check collision against disk
  collision_disk_inst : entity work.collision_disk
    generic map (
      G_ACCURACY => G_ACCURACY,
      G_POS_BITS => G_POS_BITS,
      G_VEL_BITS => G_VEL_BITS
    )
    port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      s_ready_o      => disk_s_ready,
      s_valid_i      => disk_s_valid,
      s_a_pos_x_i    => disk_s_a_pos_x,
      s_a_pos_y_i    => disk_s_a_pos_y,
      s_a_vel_x_i    => disk_s_a_vel_x,
      s_a_vel_y_i    => disk_s_a_vel_y,
      s_a_radius_i   => disk_s_a_radius,
      s_b_center_x_i => disk_s_b_center_x,
      s_b_center_y_i => disk_s_b_center_y,
      s_b_radius_i   => disk_s_b_radius,
      m_ready_i      => '1',
      m_valid_o      => disk_m_valid,
      m_a_vel_x_o    => disk_m_vel_x,
      m_a_vel_y_o    => disk_m_vel_y
    ); -- collision_disk_inst : entity work.collision_disk

  -- Check collision against line
  collision_line_inst : entity work.collision_line
    generic map (
      G_ACCURACY => G_ACCURACY,
      G_POS_BITS => G_POS_BITS,
      G_VEL_BITS => G_VEL_BITS
    )
    port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      s_ready_o      => line_s_ready,
      s_valid_i      => line_s_valid,
      s_a_pos_x_i    => line_s_a_pos_x,
      s_a_pos_y_i    => line_s_a_pos_y,
      s_a_vel_x_i    => line_s_a_vel_x,
      s_a_vel_y_i    => line_s_a_vel_y,
      s_a_radius_i   => line_s_a_radius,
      s_b_point_x_i  => line_s_b_point_x,
      s_b_point_y_i  => line_s_b_point_y,
      s_b_normal_x_i => line_s_b_normal_x,
      s_b_normal_y_i => line_s_b_normal_y,
      m_ready_i      => '1',
      m_valid_o      => line_m_valid,
      m_a_vel_x_o    => line_m_vel_x,
      m_a_vel_y_o    => line_m_vel_y
    ); -- collision_inst : entity work.collision

  ball_pos_x_o <= s_pos_x;
  ball_pos_y_o <= s_pos_y;
  ball_vel_x_o <= s_vel_x;
  ball_vel_y_o <= s_vel_y;

end architecture synthesis;

