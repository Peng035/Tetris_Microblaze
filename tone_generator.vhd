----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2024/03/04 14:36:07
-- Design Name: 
-- Module Name: tone_generator - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tone_generator is
    Port ( clk : in STD_LOGIC;
           volume : in integer;
           tone_index : in integer;     -- shifted by 11 tone index
           AUD_PWM : out STD_LOGIC;
           AUD_SD : out STD_LOGIC);
end tone_generator;

architecture Behavioral of tone_generator is

constant MAX_VOLUME : integer := 10;

-- the counter to generate correct freq
signal  cnt : integer range 0 to 5e6;
signal  TOTAL_CNT : integer range 0 to 5e5;
-- temp buffere to store the value for PWM
signal temp: std_logic;
-- counter to set volume
signal vol_cnt: integer range 0 to 100 :=0;

signal tone_period_buff : integer range 0 to 1e6;

begin

 GEN_PWM_PROC:  process(clk)
        begin
            if rising_edge (clk) then
            
--                -- lookup table for tones
--                case tone_index is 
--                    when 0      =>   TOTAL_CNT <= 0 ;
--                    when 1      =>   TOTAL_CNT <= 406504 ;                 
--                    when 2      =>   TOTAL_CNT <= 383141 ;                 
--                    when 3      =>   TOTAL_CNT <= 361010 ;                 
--                    when 4      =>   TOTAL_CNT <= 341296 ;                 
--                    when 5      =>   TOTAL_CNT <= 321543 ;                 
--                    when 6      =>   TOTAL_CNT <= 303951 ;                 
--                    when 7      =>   TOTAL_CNT <= 286532 ;                 
--                    when 8      =>   TOTAL_CNT <= 271002 ;                 
--                    when 9      =>   TOTAL_CNT <= 255754 ;                 
--                    when 10     =>   TOTAL_CNT <= 240963 ;                 
--                    when 11     =>   TOTAL_CNT <= 227272 ;      -- 440HZ   
--                    when 12     =>   TOTAL_CNT <= 214592 ;                 
--                    when 13     =>   TOTAL_CNT <= 202839 ;                 
--                    when 14     =>   TOTAL_CNT <= 191204 ;                 
--                    when 15     =>   TOTAL_CNT <= 180505 ;                 
--                    when 16     =>   TOTAL_CNT <= 170357 ;                 
--                    when 17     =>   TOTAL_CNT <= 160771 ;                 
--                    when 18     =>   TOTAL_CNT <= 151745 ;                 
--                    when 19     =>   TOTAL_CNT <= 143266 ;                 
--                    when 20     =>   TOTAL_CNT <= 135317 ;                 
--                    when 21     =>   TOTAL_CNT <= 127713 ;                 
--                    when 22     =>   TOTAL_CNT <= 120481 ;                 
--                    when 23     =>   TOTAL_CNT <= 113636 ;                 
--                    when 24     =>   TOTAL_CNT <= 107296 ;                 
--                    when 25     =>   TOTAL_CNT <= 101317 ;                 
--                    when 26     =>   TOTAL_CNT <= 95602  ;                 
--                    when 27     =>   TOTAL_CNT <= 90252  ;                 
--                    when 28     =>   TOTAL_CNT <= 85178  ;                 
--                    when 29     =>   TOTAL_CNT <= 80385  ;                 
--                    when 30     =>   TOTAL_CNT <= 75872  ;                 
--                    when 31     =>   TOTAL_CNT <= 71633  ;                 
--                    when others => 
--                end case;     

                -- lookup table for tones
                case tone_index is 
                    when 0      =>   TOTAL_CNT <= 0 ;
                    when 1      =>   TOTAL_CNT <= 203200 ;                 
                    when 2      =>   TOTAL_CNT <= 191500 ;                 
                    when 3      =>   TOTAL_CNT <= 180500 ;                 
                    when 4      =>   TOTAL_CNT <= 170600 ;                 
                    when 5      =>   TOTAL_CNT <= 160700 ;                 
                    when 6      =>   TOTAL_CNT <= 151900 ;                 
                    when 7      =>   TOTAL_CNT <= 143200 ;                 
                    when 8      =>   TOTAL_CNT <= 135500 ;                 
                    when 9      =>   TOTAL_CNT <= 127800 ;                 
                    when 10     =>   TOTAL_CNT <= 120400 ;                 
                    when 11     =>   TOTAL_CNT <= 113600 ;      -- 440HZ   
                    when 12     =>   TOTAL_CNT <= 107200 ;                 
                    when 13     =>   TOTAL_CNT <= 101400 ;                 
                    when 14     =>   TOTAL_CNT <= 95600 ;                 
                    when 15     =>   TOTAL_CNT <= 90200 ;                 
                    when 16     =>   TOTAL_CNT <= 85100 ;                 
                    when 17     =>   TOTAL_CNT <= 80300 ;                 
                    when 18     =>   TOTAL_CNT <= 75800 ;                 
                    when 19     =>   TOTAL_CNT <= 71600 ;                 
                    when 20     =>   TOTAL_CNT <= 67600 ;                 
                    when 21     =>   TOTAL_CNT <= 63800 ;                 
                    when 22     =>   TOTAL_CNT <= 60200 ;                 
                    when 23     =>   TOTAL_CNT <= 56800 ;                 
                    when 24     =>   TOTAL_CNT <= 53600 ;                 
                    when 25     =>   TOTAL_CNT <= 50600 ;                 
                    when 26     =>   TOTAL_CNT <= 47800 ;                 
                    when 27     =>   TOTAL_CNT <= 45100 ;                 
                    when 28     =>   TOTAL_CNT <= 42500 ;                 
                    when 29     =>   TOTAL_CNT <= 40100 ;                 
                    when 30     =>   TOTAL_CNT <= 37900 ;                 
                    when 31     =>   TOTAL_CNT <= 35800 ;                 
                    when others => 
                end case; 
                
                if TOTAL_CNT > 0 then
                    if cnt < TOTAL_CNT then
                        cnt <= cnt + 1;
                    else 
                        cnt <= 0;
                        temp <= temp XOR '1';
                    end if; 
                 else       -- index 0 means silence
                    temp <= '1';     
                 end if;        
            end if;
        end process GEN_PWM_PROC;
    
  OUTPUT_PORC: process(temp)
    begin     
       if temp = '1' then
            AUD_PWM <= 'Z'; 
       else 
           AUD_PWM <= temp;
       end if;
   end process OUTPUT_PORC;
   
--   VOLUME_PROC: process(clk)
--    begin
--        if rising_edge (clk) then
--            if vol_cnt < MAX_VOLUME - volume then
--                vol_cnt <= vol_cnt+1;
--                AUD_SD <= '0';
--            else
--                vol_cnt <= 0;
--                AUD_SD <= '1';
--            end if;
--        end if;
--   end process VOLUME_PROC;

   AUD_SD <= '1';

end Behavioral;
