library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.fixed_float_types.all;
  use ieee.fixed_pkg.all;

entity adder is
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
    s_a_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);
    s_b_i     : in    sfixed(G_BITS - 1 downto -G_ACCURACY);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_res_o   : out   sfixed(G_BITS - 1 downto -G_ACCURACY)
  );
end entity adder;

architecture synthesis of adder is

begin

  reg_gen : if G_REG generate
    s_ready_o <= m_ready_i or not m_valid_o;

    adder_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if m_ready_i = '1' then
          m_valid_o <= '0';
        end if;

        if s_valid_i = '1' and s_ready_o = '1' then
          m_res_o   <= resize(s_a_i + s_b_i, m_res_o,
                              round_style    => fixed_truncate,
                              overflow_style => fixed_wrap);
          m_valid_o <= '1';
        end if;

        if rst_i = '1' then
          m_valid_o <= '0';
        end if;
      end if;
    end process adder_proc;

  else generate
    m_res_o   <= resize(s_a_i + s_b_i, m_res_o,
                        round_style    => fixed_truncate,
                        overflow_style => fixed_wrap);
  end generate reg_gen;

end architecture synthesis;

