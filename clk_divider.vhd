library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Clock_Divider is
    Port (
        clk : in  std_logic;        -- System clock input
        rst : in  std_logic;        -- Reset input
        clk_out : out std_logic     -- Lower frequency clock output
    );
end Clock_Divider;

architecture Behavioral of Clock_Divider is
    constant DIVIDER : integer := 10;  -- Clock division ratio
    signal counter : integer range 0 to DIVIDER - 1 := 0;  -- Counter for clock division
    signal clk_out_int : std_logic := '0';  -- Intermediate clock signal
begin
    process(clk, rst)
    begin
        if rst = '1' then
            counter <= 0;  -- Reset counter on reset signal
            clk_out_int <= '0';  -- Reset intermediate clock signal
        elsif rising_edge(clk) then
            -- Increment counter
            counter <= counter + 1;
            -- Generate intermediate clock signal
            if counter = DIVIDER - 1 then
                clk_out_int <= not clk_out_int;  -- Toggle intermediate clock signal
                counter <= 0;  -- Reset counter
            end if;
        end if;
    end process;

    -- Assign intermediate clock signal to the output
    clk_out <= clk_out_int;
end Behavioral;