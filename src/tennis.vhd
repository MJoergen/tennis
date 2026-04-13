library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.sprite_pkg.all;

entity tennis is
  generic (
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

  constant C_BITMAP_PLAYER : bitmap_type   := (
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

  constant C_BITMAP_COMPUTER : bitmap_type := C_BITMAP_PLAYER;

  constant C_BITMAP_BALL : bitmap_type     := (
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

  constant C_SPRITE_PLAYER   : natural     := 0;
  constant C_SPRITE_COMPUTER : natural     := 1;
  constant C_SPRITE_BALL     : natural     := 2;

  constant C_SIZE_SPRITE : natural         := 16;

  constant C_POS_Y_PLAYER   : natural      := G_SCREEN_Y - C_SIZE_SPRITE;
  constant C_POS_Y_COMPUTER : natural      := G_SCREEN_Y - C_SIZE_SPRITE;

  signal   player_x   : natural range 0 to 2047 := G_SCREEN_X / 4;
  signal   computer_x : natural range 0 to 2047 := (G_SCREEN_X * 3) / 4;
  signal   ball_x     : natural range 0 to 2047 := G_SCREEN_X / 2;
  signal   ball_y     : natural range 0 to 2047 := G_SCREEN_Y / 2;

begin

  sprites_o(C_SPRITE_PLAYER)   <=
  (
    pos_x  => player_x,
    pos_y  => C_POS_Y_PLAYER,
    bitmap => C_BITMAP_PLAYER,
    color  => C_COLOR_GREEN,
    active => '1'
  );

  sprites_o(C_SPRITE_COMPUTER) <=
  (
    pos_x  => computer_x,
    pos_y  => C_POS_Y_COMPUTER,
    bitmap => C_BITMAP_COMPUTER,
    color  => C_COLOR_RED,
    active => '1'
  );

  sprites_o(C_SPRITE_BALL)     <=
  (
    pos_x  => ball_x,
    pos_y  => ball_y,
    bitmap => C_BITMAP_BALL,
    color  => C_COLOR_YELLOW,
    active => '1'
  );

end architecture synthesis;

