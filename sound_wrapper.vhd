----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2024/04/02 20:27:52
-- Design Name: 
-- Module Name: sound_wrapper - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sound_wrapper is
    Port ( clk : in STD_LOGIC;
           aud_pwm : out STD_LOGIC;
           aud_sd : out STD_LOGIC;
           rst : in STD_LOGIC;
           enable : in STD_LOGIC;
           volume_up : in STD_LOGIC;
           volume_down : in STD_LOGIC;
           mute : in STD_LOGIC);
end sound_wrapper;

architecture Behavioral of sound_wrapper is

component music_player is
  Port (    clk:        in std_logic;
            rst:        in std_logic;
            enable:    in std_logic;
            mute:       in std_logic;
            vol_up:     in std_logic;
            vol_down:   in std_logic;
            AUD_PWM:    out std_logic;
            AUD_SD:     out std_logic   
   );
end component;

component Clock_Divider is
    Port (
        clk : in  std_logic;        -- System clock input
        rst : in  std_logic;        -- Reset input
        clk_out : out std_logic     -- Lower frequency clock output
    );
end component;

signal aud_pwm_internal: std_logic; 
signal aud_sd_internal: std_logic;
signal clk_internal: std_logic;

begin
    music_inst: component music_player
        port map(
            clk => clk_internal,     
            rst => rst,
            enable => enable,  
            mute => mute,   
            vol_up => volume_up, 
            vol_down => volume_down,
            AUD_PWM => aud_pwm,
            AUD_SD => aud_sd  
        );
        
     clk_divider_inst: component Clock_Divider
        port map (
            clk => clk,
            rst => rst,
            clk_out => clk_internal
        ); 

end Behavioral;
