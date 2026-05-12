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
    ball_pos_x_o : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_pos_y_o : out   ufixed(G_POS_BITS - 1 downto - G_ACCURACY);
    ball_vel_x_o : out   sfixed(G_VEL_BITS - 1 downto - G_ACCURACY);
    ball_vel_y_o : out   sfixed(G_VEL_BITS - 1 downto - G_ACCURACY)
  );
end entity ball;

architecture synthesis of ball is

  constant C_GRAVITY : natural := 1;

  type     state_type is (IDLE_ST, PLAYER_ST, COMPUTER_ST);
  signal   state : state_type  := IDLE_ST;

  signal   s_ready    : std_logic;
  signal   s_valid    : std_logic;
  signal   s_pos_x    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   s_pos_y    : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   s_vel_x    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s_vel_y    : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   s_center_x : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);
  signal   s_center_y : ufixed(G_POS_BITS - 1 downto -G_ACCURACY);

  signal   m_valid : std_logic;
  signal   m_vel_x : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);
  signal   m_vel_y : sfixed(G_VEL_BITS - 1 downto -G_ACCURACY);

begin

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready = '1' then
        s_valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if ce_i = '1' then
            s_pos_x    <= s_pos_x;
            s_pos_y    <= s_pos_y;
            s_vel_x    <= s_vel_x;
            s_vel_y    <= s_vel_y;
            s_center_x <= player_x_i;
            s_center_y <= player_y_i;
            s_valid    <= '1';
            state      <= PLAYER_ST;
          end if;

        when PLAYER_ST =>
          if m_valid = '1' then
            s_vel_x    <= m_vel_x;
            s_vel_y    <= m_vel_y;
            s_center_x <= computer_x_i;
            s_center_y <= computer_y_i;
            s_valid    <= '1';
            state      <= COMPUTER_ST;
          end if;

        when COMPUTER_ST =>
          if m_valid = '1' then
            s_vel_x <= m_vel_x;
            s_vel_y <= resize(m_vel_y + C_GRAVITY, s_vel_y);
            s_pos_x <= resize(ufixed(sfixed(s_pos_x) + s_vel_x), s_pos_x);
            s_pos_y <= resize(ufixed(sfixed(s_pos_y) + s_vel_y), s_pos_y);
            state   <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_valid <= '0';
        s_pos_x <= to_ufixed(G_SCREEN_X / 2, G_POS_BITS - 1, - G_ACCURACY);
        s_pos_y <= to_ufixed(G_SCREEN_Y / 2, G_POS_BITS - 1, - G_ACCURACY);
        s_vel_x <= to_sfixed(0, G_VEL_BITS - 1, - G_ACCURACY);
        s_vel_y <= to_sfixed(0, G_VEL_BITS - 1, - G_ACCURACY);
      end if;
    end if;
  end process fsm_proc;


  -- Check collision
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
      s_ready_o    => s_ready,
      s_valid_i    => s_valid,
      s_pos_x_i    => s_pos_x,
      s_pos_y_i    => s_pos_y,
      s_vel_x_i    => s_vel_x,
      s_vel_y_i    => s_vel_y,
      s_center_x_i => s_center_x,
      s_center_y_i => s_center_y,
      m_ready_i    => '1',
      m_valid_o    => m_valid,
      m_vel_x_o    => m_vel_x,
      m_vel_y_o    => m_vel_y
    ); -- collision_inst : entity work.collision

  ball_pos_x_o <= s_pos_x;
  ball_pos_y_o <= s_pos_y;
  ball_vel_x_o <= s_vel_x;
  ball_vel_y_o <= s_vel_y;

end architecture synthesis;

