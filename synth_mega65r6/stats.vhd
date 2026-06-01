library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity stats is
  generic (
    G_DATA_SIZE : natural;
    G_ACCURACY  : natural
  );
  port (
    clk_i         : in    std_logic;
    rst_i         : in    std_logic;
    s_ready_o     : out   std_logic;
    s_valid_i     : in    std_logic;
    s_data_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_ready_i     : in    std_logic;
    m_valid_o     : out   std_logic;
    m_min_val_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_max_val_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_mean_val_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_mean_diff_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity stats;

architecture synthesis of stats is

begin

  s_ready_o <= '1';

  stats_proc : process (clk_i)
    variable diff_v     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
    variable abs_diff_v : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_valid_i = '1' then
        if m_valid_o = '0' then
          m_min_val_o   <= s_data_i;
          m_max_val_o   <= s_data_i;
          m_mean_val_o  <= s_data_i;
          m_mean_diff_o <= (others => '0');
        else
          if s_data_i < m_min_val_o then
            m_min_val_o <= s_data_i;
          end if;

          if s_data_i > m_max_val_o then
            m_max_val_o <= s_data_i;
          end if;

          diff_v       := std_logic_vector(signed(s_data_i) - signed(m_mean_val_o));
          m_mean_val_o <= std_logic_vector(signed(m_mean_val_o) + shift_right(signed(diff_v), G_ACCURACY));

          abs_diff_v   := diff_v;
          if signed(diff_v) < 0 then
            abs_diff_v := std_logic_vector(-signed(diff_v));
          end if;

          diff_v        := std_logic_vector(signed(abs_diff_v) - signed(m_mean_diff_o));
          m_mean_diff_o <= std_logic_vector(signed(m_mean_diff_o) + shift_right(signed(diff_v), G_ACCURACY));
        end if;
        m_valid_o <= '1';
      end if;

      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process stats_proc;

end architecture synthesis;

