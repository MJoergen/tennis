library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

library work;
  use work.sprite_pkg.all;

entity tennis is
  generic (
    G_ACCURACY : natural;
    G_SCREEN_X : natural range 0 to 2047;
    G_SCREEN_Y : natural range 0 to 2047
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;
    ce_i        : in    std_logic;
    btn_left_i  : in    std_logic;
    btn_right_i : in    std_logic;
    sprites_o   : out   sprite_array_type
  );
end entity tennis;

architecture synthesis of tennis is

  constant C_BITMAP_PLAYER : bitmap_type        := (
                                                0  => "0000111111100000",
                                                1  => "0011111111111000",
                                                2  => "0111111111111100",
                                                3  => "0111111111111100",
                                                4  => "1111111111111110",
                                                5  => "1111111111111110",
                                                6  => "1111111111111110",
                                                7  => "1111111111111110",
                                                8  => "0000000000000000",
                                                9  => "0000000000000000",
                                                10 => "0000000000000000",
                                                11 => "0000000000000000",
                                                12 => "0000000000000000",
                                                13 => "0000000000000000",
                                                14 => "0000000000000000",
                                                15 => "0000000000000000"
                                              );

  constant C_BITMAP_COMPUTER : bitmap_type      := C_BITMAP_PLAYER;

  constant C_BITMAP_BALL : bitmap_type          := (
                                                0  => "0000111111100000",
                                                1  => "0011111111111000",
                                                2  => "0111111111111100",
                                                3  => "0111111111111100",
                                                4  => "1111111111111110",
                                                5  => "1111111111111110",
                                                6  => "1111111111111110",
                                                7  => "1111111111111110",
                                                8  => "1111111111111110",
                                                9  => "1111111111111110",
                                                10 => "1111111111111110",
                                                11 => "0111111111111100",
                                                12 => "0111111111111100",
                                                13 => "0011111111111000",
                                                14 => "0000111111100000",
                                                15 => "0000000000000000"
                                              );

  constant C_SPRITE_PLAYER   : natural          := 0;
  constant C_SPRITE_COMPUTER : natural          := 1;
  constant C_SPRITE_BALL     : natural          := 2;

  constant C_SIZE_SPRITE : natural              := 16;

  constant C_POS_BITS : natural := 11;
  constant C_VEL_BITS : natural := 11;

  constant C_INIT_PLAYER_X   : natural := G_SCREEN_X / 4;
  constant C_INIT_PLAYER_Y   : natural := G_SCREEN_Y - C_SIZE_SPRITE;
  constant C_INIT_COMPUTER_X : natural := (G_SCREEN_X * 3) / 4;
  constant C_INIT_COMPUTER_Y : natural := G_SCREEN_Y - C_SIZE_SPRITE;
  constant C_INIT_BALL_X     : natural := G_SCREEN_X / 2;
  constant C_INIT_BALL_Y     : natural := G_SCREEN_Y / 2;

  signal   player_x   : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_PLAYER_X,   C_POS_BITS - 1, - G_ACCURACY);
  signal   player_y   : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_PLAYER_Y,   C_POS_BITS - 1, - G_ACCURACY);
  signal   computer_x : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_COMPUTER_X, C_POS_BITS - 1, - G_ACCURACY);
  signal   computer_y : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_COMPUTER_Y, C_POS_BITS - 1, - G_ACCURACY);
  signal   ball_x     : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_BALL_X,     C_POS_BITS - 1, - G_ACCURACY);
  signal   ball_y     : ufixed(C_POS_BITS - 1 downto - G_ACCURACY) := to_ufixed(C_INIT_BALL_Y,     C_POS_BITS - 1, - G_ACCURACY);

begin

  sprites_o(C_SPRITE_PLAYER)   <=
  (
    pos_x  => to_integer(unsigned(to_slv(player_x))),
    pos_y  => to_integer(unsigned(to_slv(player_y))),
    bitmap => C_BITMAP_PLAYER,
    color  => C_COLOR_GREEN,
    active => '1'
  );

  sprites_o(C_SPRITE_COMPUTER) <=
  (
    pos_x  => to_integer(unsigned(to_slv(computer_x))),
    pos_y  => to_integer(unsigned(to_slv(computer_y))),
    bitmap => C_BITMAP_COMPUTER,
    color  => C_COLOR_RED,
    active => '1'
  );

  sprites_o(C_SPRITE_BALL)     <=
  (
    pos_x  => to_integer(unsigned(to_slv(ball_x))),
    pos_y  => to_integer(unsigned(to_slv(ball_y))),
    bitmap => C_BITMAP_BALL,
    color  => C_COLOR_YELLOW,
    active => '1'
  );


  -- Instantiate ball movement
  ball_inst : entity work.ball
    generic map (
      G_POS_BITS => C_POS_BITS,
      G_VEL_BITS => C_VEL_BITS,
      G_ACCURACY => G_ACCURACY,
      G_SCREEN_X => G_SCREEN_X,
      G_SCREEN_Y => G_SCREEN_Y
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      ce_i         => ce_i,
      player_x_i   => player_x,
      player_y_i   => player_y,
      computer_x_i => computer_x,
      computer_y_i => computer_y,
      ball_x_o     => ball_x,
      ball_y_o     => ball_y
    ); -- ball_inst : entity work.ball

end architecture synthesis;

